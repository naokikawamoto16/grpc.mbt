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
/// Transport security mode for a channel.
pub(all) enum Security {
  Insecure
  Tls(TlsOptions)
} derive(Show, Eq, ToJson)

///|
/// Basic TLS options for channel creation.
///
/// - `private_key` and `cert_chain` must be set together (mutual TLS) or both omitted.
/// - `reject_unauthorized` controls whether the server certificate is verified.
///   When `None`, the backend's default behavior is used (typically `true`).
pub(all) struct TlsOptions {
  root_certs : Bytes?
  private_key : Bytes?
  cert_chain : Bytes?
  server_name_override : String?
  reject_unauthorized : Bool?
} derive(Show, Eq, ToJson)

///|
/// Channel-level gRPC options.
pub(all) struct ChannelOptions {
  security : Security
  max_send_message_length : Int?
  max_receive_message_length : Int?
  keepalive_time_ms : Int?
  keepalive_timeout_ms : Int?
  default_authority : String?
  user_agent : String?
} derive(Show, Eq, ToJson)

///|
/// Per-call options for unary requests.
pub(all) struct CallOptions {
  metadata : Metadata
  timeout_ms : Int?
  wait_for_ready : Bool
} derive(Show, Eq, ToJson)

///|
fn default_channel_options() -> ChannelOptions {
  {
    security: Insecure,
    max_send_message_length: None,
    max_receive_message_length: None,
    keepalive_time_ms: None,
    keepalive_timeout_ms: None,
    default_authority: None,
    user_agent: None,
  }
}

///|
fn default_call_options() -> CallOptions {
  { metadata: Metadata::new(), timeout_ms: None, wait_for_ready: false }
}

///|
fn validate_tls_options(options : TlsOptions) -> Result[Unit, RpcError] {
  if options.server_name_override is Some(name) && name.length() == 0 {
    return Err(invalid_argument_error("server_name_override must not be empty"))
  }

  match (options.private_key, options.cert_chain) {
    (Some(_), None) | (None, Some(_)) =>
      Err(
        invalid_argument_error(
          "private_key and cert_chain must be set together",
        ),
      )
    _ => Ok(())
  }
}

///|
fn validate_channel_options(options : ChannelOptions) -> Result[Unit, RpcError] {
  match options.security {
    Insecure => Ok(())
    Tls(tls) => validate_tls_options(tls)
  }
}
