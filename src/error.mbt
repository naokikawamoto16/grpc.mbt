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
/// Convert a backend-layer `BackendError` into a public `RpcError`.
///
/// The status code is decoded from the integer representation, the error kind
/// string is mapped to `RpcErrorKind`, and raw metadata
/// arrays are reassembled into a `Metadata` value.
fn normalize_backend_error(error : @internal.BackendError) -> RpcError {
  let code = status_code_from_int(error.code)
  let kind = match error.kind {
    "status" => Status
    "transport" => Transport
    "timeout" => Timeout
    "cancelled" => Cancelled
    "codec_encode" => CodecEncode
    "codec_decode" => CodecDecode
    "channel_closed" => ChannelClosed
    _ => Internal
  }
  {
    code,
    message: error.message,
    details: error.details,
    metadata: metadata_from_backend(error.metadata_text, error.metadata_binary),
    kind,
  }
}
