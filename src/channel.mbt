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
/// A reusable gRPC channel handle.
pub struct Channel {
  priv handle : @internal.ChannelHandle
}

///|
/// Create a channel for a target endpoint.
/// Returns `Err(RpcError)` when the target or options are invalid,
/// or when backend initialization fails.
pub fn Channel::new(
  target : String,
  options? : ChannelOptions = default_channel_options(),
) -> Result[Channel, RpcError] {
  if target.trim().length() == 0 {
    return Err(invalid_argument_error("target must not be empty"))
  }
  validate_channel_options(options).bind(_ => {
    match @internal.new_channel(target, to_backend_channel_options(options)) {
      Ok(handle) => Ok({ handle, })
      Err(error) => Err(normalize_backend_error(error))
    }
  })
}

///|
/// Close the channel.
/// This method is idempotent.
pub fn Channel::close(self : Channel) -> Unit {
  @internal.close_channel(self.handle)
}

///|
/// Returns `true` when the channel has been closed.
pub fn Channel::is_closed(self : Channel) -> Bool {
  @internal.is_channel_closed(self.handle)
}

///|
fn to_backend_security(security : Security) -> @internal.BackendSecurity {
  match security {
    Insecure => @internal.Insecure
    Tls(options) =>
      @internal.Tls({
        root_certs: options.root_certs,
        private_key: options.private_key,
        cert_chain: options.cert_chain,
        server_name_override: options.server_name_override,
        reject_unauthorized: options.reject_unauthorized,
      })
  }
}

///|
fn to_backend_channel_options(
  options : ChannelOptions,
) -> @internal.BackendChannelOptions {
  {
    security: to_backend_security(options.security),
    max_send_message_length: options.max_send_message_length,
    max_receive_message_length: options.max_receive_message_length,
    keepalive_time_ms: options.keepalive_time_ms,
    keepalive_timeout_ms: options.keepalive_timeout_ms,
    default_authority: options.default_authority,
    user_agent: options.user_agent,
  }
}
