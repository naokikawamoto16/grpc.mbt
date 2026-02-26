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
/// - `server_name_override`, when set, must not be blank.
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
///
/// - `max_send_message_length` and `max_receive_message_length` must be `-1`
///   (unlimited) or a non-negative integer when set.
/// - `keepalive_time_ms` and `keepalive_timeout_ms` must be a positive integer
///   when set.
/// - `default_authority` and `user_agent`, when set, must not be blank.
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
fn validate_optional_non_blank(
  field_name : String,
  value : String?,
) -> Result[Unit, RpcError] {
  match value {
    Some(text) if text.trim().length() == 0 =>
      Err(invalid_argument_error("\{field_name} must not be empty"))
    _ => Result::Ok(())
  }
}

///|
fn validate_optional_positive_int(
  field_name : String,
  value : Int?,
) -> Result[Unit, RpcError] {
  match value {
    Some(number) if number <= 0 =>
      Err(invalid_argument_error("\{field_name} must be a positive integer"))
    _ => Result::Ok(())
  }
}

///|
fn validate_optional_message_length(
  field_name : String,
  value : Int?,
) -> Result[Unit, RpcError] {
  match value {
    Some(number) if number < -1 =>
      Err(invalid_argument_error("\{field_name} must be >= -1"))
    _ => Result::Ok(())
  }
}

///|
fn validate_tls_options(options : TlsOptions) -> Result[Unit, RpcError] {
  validate_optional_non_blank(
    "server_name_override",
    options.server_name_override,
  ).bind(_ => {
    match (options.private_key, options.cert_chain) {
      (Some(_), None) | (None, Some(_)) =>
        Err(
          invalid_argument_error(
            "private_key and cert_chain must be set together",
          ),
        )
      _ => Result::Ok(())
    }
  })
}

///|
fn validate_channel_options(options : ChannelOptions) -> Result[Unit, RpcError] {
  let security_result = match options.security {
    Security::Insecure => Result::Ok(())
    Security::Tls(tls) => validate_tls_options(tls)
  }
  security_result
  .bind(_ => {
    validate_optional_message_length(
      "max_send_message_length",
      options.max_send_message_length,
    )
  })
  .bind(_ => {
    validate_optional_message_length(
      "max_receive_message_length",
      options.max_receive_message_length,
    )
  })
  .bind(_ => {
    validate_optional_positive_int(
      "keepalive_time_ms",
      options.keepalive_time_ms,
    )
  })
  .bind(_ => {
    validate_optional_positive_int(
      "keepalive_timeout_ms",
      options.keepalive_timeout_ms,
    )
  })
  .bind(_ => {
    validate_optional_non_blank("default_authority", options.default_authority)
  })
  .bind(_ => validate_optional_non_blank("user_agent", options.user_agent))
}
