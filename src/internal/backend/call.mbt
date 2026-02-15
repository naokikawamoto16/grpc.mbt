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
pub struct UnaryCall {
  priv inner : @impl.UnaryCall
}

///|
fn to_impl_call_options(options : RawCallOptions) -> @impl.RawCallOptions {
  {
    metadata_text: options.metadata_text,
    metadata_binary: options.metadata_binary,
    timeout_ms: options.timeout_ms,
    wait_for_ready: options.wait_for_ready,
  }
}

///|
fn raw_error_kind_from_string(kind : String) -> RawErrorKind {
  match kind {
    "status" => Status
    "transport" => Transport
    "timeout" => Timeout
    "cancelled" => Cancelled
    "codec_encode" => CodecEncode
    "codec_decode" => CodecDecode
    "channel_closed" => ChannelClosed
    _ => Internal
  }
}

///|
fn from_impl_raw_error(error : @impl.RawError) -> RawError {
  {
    code: error.code,
    message: error.message,
    details: error.details,
    metadata_text: error.metadata_text,
    metadata_binary: error.metadata_binary,
    kind: raw_error_kind_from_string(error.kind),
  }
}

///|
fn from_impl_outcome(outcome : @impl.RawUnaryOutcome) -> RawUnaryOutcome {
  match outcome {
    @impl.Success(payload) => Success(payload)
    @impl.Failure(error) => Failure(from_impl_raw_error(error))
  }
}

///|
fn wrap_unary_call(call : @impl.UnaryCall) -> UnaryCall {
  { inner: call }
}

///|
pub fn start_unary(
  channel : Channel,
  path : String,
  request : Bytes,
  options : RawCallOptions,
) -> Result[UnaryCall, RawError] {
  @impl.start_unary(channel.inner, path, request, to_impl_call_options(options))
  .map(wrap_unary_call)
  .map_err(from_impl_raw_error)
}

///|
pub fn[Req] start_unary_with_codec(
  channel : Channel,
  path : String,
  request : Req,
  encode : (Req) -> Bytes raise,
  options : RawCallOptions,
) -> Result[UnaryCall, RawError] {
  @impl.start_unary_with_codec(
    channel.inner,
    path,
    request,
    encode,
    to_impl_call_options(options),
  )
  .map(wrap_unary_call)
  .map_err(from_impl_raw_error)
}

///|
pub fn cancel_unary(call : UnaryCall) -> Unit {
  @impl.cancel_unary(call.inner)
}

///|
pub fn is_unary_done(call : UnaryCall) -> Bool {
  @impl.is_unary_done(call.inner)
}

///|
pub async fn await_unary(call : UnaryCall) -> RawUnaryOutcome {
  from_impl_outcome(@impl.await_unary(call.inner))
}

///|
pub async fn[Resp] await_unary_with_codec(
  call : UnaryCall,
  decode : (Bytes) -> Resp raise,
) -> Result[Resp, RawError] {
  @impl.await_unary_with_codec(call.inner, decode).map_err(from_impl_raw_error)
}
