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
pub(all) struct RawTlsOptions {
  root_certs : Bytes?
  private_key : Bytes?
  cert_chain : Bytes?
  server_name_override : String?
  reject_unauthorized : Bool?
} derive(Show, Eq, ToJson)

///|
pub(all) enum RawSecurity {
  Insecure
  Tls(RawTlsOptions)
} derive(Show, Eq, ToJson)

///|
pub(all) struct RawChannelOptions {
  security : RawSecurity
  max_send_message_length : Int?
  max_receive_message_length : Int?
  keepalive_time_ms : Int?
  keepalive_timeout_ms : Int?
  default_authority : String?
  user_agent : String?
} derive(Show, Eq, ToJson)

///|
pub struct Channel {
  priv inner : JsChannel
}

///|
fn security_to_args(
  security : RawSecurity,
) -> (Bool, Bytes?, Bytes?, Bytes?, String?, Bool?) {
  match security {
    Insecure => (true, None, None, None, None, None)
    Tls(options) =>
      (
        false,
        options.root_certs,
        options.private_key,
        options.cert_chain,
        options.server_name_override,
        options.reject_unauthorized,
      )
  }
}

///|
pub fn new_channel(
  target : String,
  options : RawChannelOptions,
) -> Result[Channel, String] {
  match ensure_grpc_js() {
    Err(message) => Err(message)
    Ok(_) => {
      let args = security_to_args(options.security)
      let result = ffi_new_channel(
        target,
        args.0,
        args.1,
        args.2,
        args.3,
        args.4,
        args.5,
        options.max_send_message_length,
        options.max_receive_message_length,
        options.keepalive_time_ms,
        options.keepalive_timeout_ms,
        options.default_authority,
        options.user_agent,
      )
      if ffi_new_channel_result_is_ok(result) {
        Ok({ inner: ffi_new_channel_result_channel(result) })
      } else {
        Err(
          ffi_new_channel_result_error(result).unwrap_or(
            "failed to create grpc-js channel",
          ),
        )
      }
    }
  }
}

///|
pub fn close_channel(channel : Channel) -> Unit {
  ffi_channel_close(channel.inner)
}

///|
pub fn is_channel_closed(channel : Channel) -> Bool {
  ffi_channel_is_closed(channel.inner)
}
