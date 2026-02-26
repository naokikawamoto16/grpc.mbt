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
fn to_impl_security(security : BackendSecurity) -> @impl.RawSecurity {
  match security {
    Insecure => @impl.Insecure
    Tls(options) =>
      @impl.Tls({
        root_certs: options.root_certs,
        private_key: options.private_key,
        cert_chain: options.cert_chain,
        server_name_override: options.server_name_override,
        reject_unauthorized: options.reject_unauthorized,
      })
  }
}

///|
fn to_impl_channel_options(
  options : BackendChannelOptions,
) -> @impl.RawChannelOptions {
  {
    security: to_impl_security(options.security),
    max_send_message_length: options.max_send_message_length,
    max_receive_message_length: options.max_receive_message_length,
    keepalive_time_ms: options.keepalive_time_ms,
    keepalive_timeout_ms: options.keepalive_timeout_ms,
    default_authority: options.default_authority,
    user_agent: options.user_agent,
  }
}

///|
fn to_impl_call_options(options : BackendCallOptions) -> @impl.RawCallOptions {
  {
    metadata_text: options.metadata_text,
    metadata_binary: options.metadata_binary,
    timeout_ms: options.timeout_ms,
    wait_for_ready: options.wait_for_ready,
  }
}

///|
pub fn new_channel(
  target : String,
  options : BackendChannelOptions,
) -> Result[ChannelHandle, BackendError] {
  match @impl.new_channel(target, to_impl_channel_options(options)) {
    Ok(channel) => Ok({ inner: channel })
    Err(message) => Err(message_error(message, kind=Transport))
  }
}

///|
pub fn close_channel(channel : ChannelHandle) -> Unit {
  @impl.close_channel(channel.inner)
}

///|
pub fn is_channel_closed(channel : ChannelHandle) -> Bool {
  @impl.is_channel_closed(channel.inner)
}

///|
fn concurrent_unary_wait_error() -> BackendError {
  message_error("concurrent unary wait is not supported", kind=InvalidUsage)
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
    @impl.start_unary_with_codec(
      channel.inner,
      path,
      request,
      encode,
      to_impl_call_options(options),
    ) {
    Ok(call) =>
      Ok({ inner: call, done: FinishOnce::new(), awaiting: false, decode })
    Err(error) => Err(from_raw_error(error))
  }
}

///|
pub fn[Resp] cancel_unary(call : UnaryHandle[Resp]) -> Unit {
  emit_debug_event(CancelTriggered)
  @impl.cancel_unary(call.inner)
}

///|
pub fn[Resp] is_unary_done(call : UnaryHandle[Resp]) -> Bool {
  call.done.is_done() || @impl.is_unary_done(call.inner)
}

///|
/// Wait for unary completion and cache the terminal result.
/// Concurrent waits on the same handle are not supported and return an error.
pub async fn[Resp] await_unary(
  call : UnaryHandle[Resp],
) -> Result[Resp, BackendError] {
  if call.done.get() is Some(result) {
    return result
  }
  if call.awaiting {
    return Err(concurrent_unary_wait_error())
  }
  call.awaiting = true
  let result = @impl.await_unary_with_codec(call.inner, call.decode).map_err(
    from_raw_error,
  )
  call.awaiting = false
  ignore(call.done.finish(result))
  result
}
