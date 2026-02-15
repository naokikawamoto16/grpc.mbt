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
fn to_raw_security(security : BackendSecurity) -> @backend.RawSecurity {
  match security {
    Insecure => @backend.Insecure
    Tls(options) =>
      @backend.Tls({
        root_certs: options.root_certs,
        private_key: options.private_key,
        cert_chain: options.cert_chain,
        server_name_override: options.server_name_override,
        reject_unauthorized: options.reject_unauthorized,
      })
  }
}

///|
fn to_raw_channel_options(
  options : BackendChannelOptions,
) -> @backend.RawChannelOptions {
  {
    security: to_raw_security(options.security),
    max_send_message_length: options.max_send_message_length,
    max_receive_message_length: options.max_receive_message_length,
    keepalive_time_ms: options.keepalive_time_ms,
    keepalive_timeout_ms: options.keepalive_timeout_ms,
    default_authority: options.default_authority,
    user_agent: options.user_agent,
  }
}

///|
fn to_raw_call_options(options : BackendCallOptions) -> @backend.RawCallOptions {
  {
    metadata_text: options.metadata_text,
    metadata_binary: options.metadata_binary,
    timeout_ms: options.timeout_ms,
    wait_for_ready: options.wait_for_ready,
  }
}

///|
fn from_raw_capabilities(
  capabilities : @backend.RawCapabilities,
) -> BackendCapabilities {
  {
    unary: capabilities.unary,
    server_streaming: capabilities.server_streaming,
    client_streaming: capabilities.client_streaming,
    bidi_streaming: capabilities.bidi_streaming,
  }
}

///|
pub fn new_channel(
  target : String,
  options : BackendChannelOptions,
) -> Result[ChannelHandle, BackendError] {
  match @backend.new_channel(target, to_raw_channel_options(options)) {
    Ok(channel) => Ok({ inner: channel })
    Err(message) => Err(message_error(message, kind=Transport))
  }
}

///|
pub fn close_channel(channel : ChannelHandle) -> Unit {
  @backend.close_channel(channel.inner)
}

///|
pub fn is_channel_closed(channel : ChannelHandle) -> Bool {
  @backend.is_channel_closed(channel.inner)
}

///|
pub fn capabilities() -> BackendCapabilities {
  from_raw_capabilities(@backend.capabilities())
}

///|
pub fn[Req, Resp] start_unary(
  channel : ChannelHandle,
  path : String,
  request : Req,
  encode : (Req) -> Bytes raise,
  decode : (Bytes) -> Resp raise,
  options : BackendCallOptions,
) -> Result[UnaryHandle[Resp], BackendError] {
  match
    @backend.start_unary_with_codec(
      channel.inner,
      path,
      request,
      encode,
      to_raw_call_options(options),
    ) {
    Ok(call) => Ok({ inner: call, done: FinishOnce::new(), decode })
    Err(error) => Err(from_raw_error(error))
  }
}

///|
pub fn[Resp] cancel_unary(call : UnaryHandle[Resp]) -> Unit {
  emit_debug_event(CancelTriggered)
  @backend.cancel_unary(call.inner)
}

///|
pub fn[Resp] is_unary_done(call : UnaryHandle[Resp]) -> Bool {
  call.done.is_done() || @backend.is_unary_done(call.inner)
}

///|
pub async fn[Resp] await_unary(
  call : UnaryHandle[Resp],
) -> Result[Resp, BackendError] {
  if call.done.get() is Some(result) {
    return result
  }
  let result = @backend.await_unary_with_codec(call.inner, call.decode).map_err(
    from_raw_error,
  )
  ignore(call.done.finish(result))
  result
}
