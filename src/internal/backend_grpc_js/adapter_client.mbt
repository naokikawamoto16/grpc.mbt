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
pub(all) struct RawCallOptions {
  metadata_text : Array[(String, Array[String])]
  metadata_binary : Array[(String, Array[Bytes])]
  timeout_ms : Int?
  wait_for_ready : Bool
} derive(Show, Eq, ToJson)

///|
pub(all) struct ConversionCounters {
  bytes_to_buffer : Int
  buffer_to_bytes : Int
} derive(Show, Eq, ToJson)

///|
pub struct UnaryCall {
  priv inner : JsUnaryCall
  priv mut cached : RawUnaryOutcome?
}

///|
fn raw_error(
  code : Int,
  message : String,
  kind : String,
  details : String?,
) -> RawError {
  { code, message, details, metadata_text: [], metadata_binary: [], kind }
}

///|
fn internal_raw_error(
  message : String,
  details : String?,
  kind? : String,
) -> RawError {
  raw_error(grpc_internal, message, kind.unwrap_or("internal"), details)
}

///|
pub fn reset_conversion_counters() -> Unit {
  ffi_reset_conversion_counters()
}

///|
pub fn conversion_counters() -> ConversionCounters {
  let values = ffi_get_conversion_counters()
  {
    bytes_to_buffer: if values.length() > 0 {
      values[0]
    } else {
      0
    },
    buffer_to_bytes: if values.length() > 1 {
      values[1]
    } else {
      0
    },
  }
}

///|
pub fn start_unary(
  channel : Channel,
  path : String,
  request : Bytes,
  options : RawCallOptions,
) -> Result[UnaryCall, RawError] {
  let text_metadata = flatten_text_metadata(options.metadata_text)
  let binary_metadata = flatten_binary_metadata(options.metadata_binary)
  let started = ffi_start_unary(
    channel.inner,
    path,
    request,
    text_metadata.0,
    text_metadata.1,
    binary_metadata.0,
    binary_metadata.1,
    options.timeout_ms,
    options.wait_for_ready,
  )
  Ok({ inner: started, cached: None })
}

///|
pub fn[Req] start_unary_with_codec(
  channel : Channel,
  path : String,
  request : Req,
  encode : (Req) -> Bytes raise,
  options : RawCallOptions,
) -> Result[UnaryCall, RawError] {
  let encoded : Result[Bytes, Error] = try? encode(request)
  match encoded {
    Ok(payload) => start_unary(channel, path, payload, options)
    Err(err) =>
      Err(
        internal_raw_error(
          "codec encode failed",
          Some(err.to_string()),
          kind="codec_encode",
        ),
      )
  }
}
