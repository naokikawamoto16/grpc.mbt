// Copyright 2026 Naoki Kawamoto

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

//     http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
/// Category of RPC failure normalized by this package.
///
/// - `Status` – the server returned a non-OK gRPC status.
/// - `Transport` – a network-level error occurred.
/// - `Timeout` – the deadline was exceeded.
/// - `Cancelled` – the call was cancelled by the caller.
/// - `InvalidArgument` – an argument passed to a public API was invalid.
/// - `CodecEncode` – encoding the request message failed.
/// - `CodecDecode` – decoding the response message failed.
/// - `ChannelClosed` – the underlying channel has been shut down.
/// - `Internal` – an unexpected error inside the library.
pub(all) enum RpcErrorKind {
  Status
  Transport
  Timeout
  Cancelled
  InvalidArgument
  CodecEncode
  CodecDecode
  ChannelClosed
  Internal
} derive(Show, Eq, Compare, Hash, ToJson)

///|
/// Unified failure object returned by all public APIs.
///
/// Every RPC failure, whether it originates from the server, the network,
/// or local validation, is represented as an `RpcError`.
pub(all) struct RpcError {
  code : StatusCode
  message : String
  details : String?
  metadata : Metadata
  kind : RpcErrorKind
} derive(Show, Eq, ToJson)

///|
/// Build an `RpcError` with the given fields.
///
/// When `metadata` is `None`, an empty `Metadata` is used.
fn rpc_error(
  code : StatusCode,
  message : String,
  kind : RpcErrorKind,
  details : String?,
  metadata : Metadata?,
) -> RpcError {
  {
    code,
    message,
    details,
    metadata: metadata.unwrap_or_else(Metadata::new),
    kind,
  }
}

///|
/// Create an `RpcError` for a public-API argument validation failure.
fn invalid_argument_error(message : String) -> RpcError {
  rpc_error(InvalidArgument, message, InvalidArgument, None, None)
}

///|
/// Create an `RpcError` indicating the channel has been shut down.
///
/// When `message` is `None`, defaults to `"channel is closed"`.
fn channel_closed_error(message : String?) -> RpcError {
  rpc_error(
    Cancelled,
    message.unwrap_or("channel is closed"),
    ChannelClosed,
    None,
    None,
  )
}

///|
fn merge_unknown_backend_kind_detail(
  details : String?,
  unknown_kind : String,
) -> String? {
  let suffix = "backend returned unknown error kind: \{unknown_kind}"
  match details {
    Some(existing) => Some("\{existing}; \{suffix}")
    None => Some(suffix)
  }
}

///|
/// Convert a backend-layer `BackendError` into a public `RpcError`.
///
/// The status code is decoded from the integer representation, the backend error
/// kind is mapped to `RpcErrorKind`, and raw metadata
/// arrays are reassembled into a `Metadata` value.
fn normalize_backend_error(error : @internal.BackendError) -> RpcError {
  let raw_code = status_code_from_int(error.code)
  let code = match error.kind {
    @internal.ChannelClosed => StatusCode::Cancelled
    _ => raw_code
  }
  let kind = match error.kind {
    @internal.Status => Status
    @internal.Transport => Transport
    @internal.Timeout => Timeout
    @internal.Cancelled => Cancelled
    @internal.CodecEncode => CodecEncode
    @internal.CodecDecode => CodecDecode
    @internal.ChannelClosed => ChannelClosed
    @internal.InvalidUsage => InvalidArgument
    @internal.Internal => Internal
    @internal.Unknown(_) => Internal
  }
  let details = match error.kind {
    @internal.Unknown(unknown_kind) =>
      merge_unknown_backend_kind_detail(error.details, unknown_kind)
    _ => error.details
  }
  {
    code,
    message: error.message,
    details,
    metadata: metadata_from_backend(error.metadata_text, error.metadata_binary),
    kind,
  }
}
