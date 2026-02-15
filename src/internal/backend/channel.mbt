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
pub struct Channel {
  priv inner : @impl.Channel
}

///|
fn to_impl_tls_options(options : RawTlsOptions) -> @impl.RawTlsOptions {
  {
    root_certs: options.root_certs,
    private_key: options.private_key,
    cert_chain: options.cert_chain,
    server_name_override: options.server_name_override,
    reject_unauthorized: options.reject_unauthorized,
  }
}

///|
fn to_impl_security(security : RawSecurity) -> @impl.RawSecurity {
  match security {
    Insecure => @impl.Insecure
    Tls(options) => @impl.Tls(to_impl_tls_options(options))
  }
}

///|
fn to_impl_channel_options(
  options : RawChannelOptions,
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
pub fn new_channel(
  target : String,
  options : RawChannelOptions,
) -> Result[Channel, String] {
  @impl.new_channel(target, to_impl_channel_options(options)).map(channel => {
    inner: channel,
  })
}

///|
pub fn close_channel(channel : Channel) -> Unit {
  @impl.close_channel(channel.inner)
}

///|
pub fn is_channel_closed(channel : Channel) -> Bool {
  @impl.is_channel_closed(channel.inner)
}
