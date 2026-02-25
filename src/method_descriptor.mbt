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
/// Immutable unary method definition used by `Client`.
pub(all) struct MethodDescriptor[Req, Resp] {
  service : String
  method_name : String
  priv path : String
  codec : Codec[Req, Resp]
}

///|
/// Build a method descriptor from service and method names.
/// The resulting RPC path is `/{service}/{method}`.
/// Returns `Err(RpcError)` when validation fails.
pub fn[Req, Resp] MethodDescriptor::new(
  service : String,
  method_name : String,
  codec : Codec[Req, Resp],
) -> Result[MethodDescriptor[Req, Resp], RpcError] {
  validate_method_name(service, method_name).bind(_ => {
    Ok({ service, method_name, path: "/\{service}/\{method_name}", codec })
  })
}

///|
/// Return the canonical gRPC path `/{service}/{method}`.
pub fn[Req, Resp] MethodDescriptor::path(
  self : MethodDescriptor[Req, Resp],
) -> String {
  self.path
}

///|
fn is_proto_ident_start(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0x41 && code <= 0x5A) || // A-Z
  (code >= 0x61 && code <= 0x7A) || // a-z
  code == 0x5F // _
}

///|
fn is_proto_ident_continue(ch : Char) -> Bool {
  let code = ch.to_int()
  is_proto_ident_start(ch) || (code >= 0x30 && code <= 0x39) // 0-9
}

///|
fn is_valid_proto_ident(value : String) -> Bool {
  let mut is_first = true
  for ch in value.iter() {
    if is_first {
      if not(is_proto_ident_start(ch)) {
        return false
      }
      is_first = false
      continue
    }
    if not(is_proto_ident_continue(ch)) {
      return false
    }
  }
  not(is_first)
}

///|
fn is_valid_service_name(service : String) -> Bool {
  let mut segment_len = 0
  for ch in service.iter() {
    if ch.to_int() == 0x2E {
      if segment_len == 0 {
        return false
      }
      segment_len = 0
      continue
    }
    if segment_len == 0 {
      if not(is_proto_ident_start(ch)) {
        return false
      }
    } else if not(is_proto_ident_continue(ch)) {
      return false
    }
    segment_len += 1
  }
  segment_len > 0
}

///|
fn is_valid_method_name_ident(method_name : String) -> Bool {
  is_valid_proto_ident(method_name)
}

///|
fn validate_method_name(
  service : String,
  method_name : String,
) -> Result[Unit, RpcError] {
  // Keep these checks for more specific error messages than the generic proto validators.
  if service.length() == 0 {
    return Err(invalid_argument_error("service must not be empty"))
  }
  if method_name.length() == 0 {
    return Err(invalid_argument_error("method must not be empty"))
  }
  if service.contains("/") {
    return Err(invalid_argument_error("service must not contain '/'"))
  }
  if method_name.contains("/") {
    return Err(invalid_argument_error("method must not contain '/'"))
  }
  if !is_valid_service_name(service) {
    return Err(
      invalid_argument_error("service must be a dot-separated proto identifier"),
    )
  }
  if !is_valid_method_name_ident(method_name) {
    return Err(invalid_argument_error("method must be a proto identifier"))
  }
  Ok(())
}
