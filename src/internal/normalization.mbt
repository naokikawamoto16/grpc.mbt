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
/// gRPC INTERNAL status code (13) used as the default for locally generated errors.
let internal_status_code : Int = 13

///|
/// gRPC CANCELLED status code (1).
let cancelled_status_code : Int = 1

///|
/// gRPC DEADLINE_EXCEEDED status code (4).
let deadline_exceeded_status_code : Int = 4

///|
/// gRPC INVALID_ARGUMENT status code (3).
let invalid_argument_status_code : Int = 3

///|
fn backend_error_kind_from_string(kind : String) -> BackendErrorKind {
  match kind {
    "status" => Status
    "transport" => Transport
    "timeout" => Timeout
    "cancelled" => Cancelled
    "codec_encode" => CodecEncode
    "codec_decode" => CodecDecode
    "channel_closed" => ChannelClosed
    "invalid_usage" => InvalidUsage
    "internal" => Internal
    _ => Unknown(kind)
  }
}

///|
fn from_raw_error(raw : @impl.RawError) -> BackendError {
  {
    code: raw.code,
    message: raw.message,
    details: raw.details,
    metadata_text: raw.metadata_text,
    metadata_binary: raw.metadata_binary,
    kind: backend_error_kind_from_string(raw.kind),
  }
}

///|
fn local_error_status_code_from_kind(kind : BackendErrorKind) -> Int {
  match kind {
    Cancelled => cancelled_status_code
    InvalidUsage => invalid_argument_status_code
    Timeout => deadline_exceeded_status_code
    _ => internal_status_code
  }
}

///|
fn message_error(message : String, kind? : BackendErrorKind) -> BackendError {
  let normalized_kind = kind.unwrap_or(Internal)
  {
    code: local_error_status_code_from_kind(normalized_kind),
    message,
    details: None,
    metadata_text: [],
    metadata_binary: [],
    kind: normalized_kind,
  }
}
