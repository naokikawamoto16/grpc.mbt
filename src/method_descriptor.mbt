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
  path : String
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
/// Check whether every character in `value` is an ASCII visible character
/// (code point 33–126, i.e. printable ASCII excluding space).
///
/// This is used to validate gRPC service and method names, which are less
/// restrictive than metadata keys (`[0-9a-z_.-]`).
fn is_ascii_visible_string(value : String) -> Bool {
  for ch in value.iter() {
    let code = ch.to_int()
    if code < 33 || code > 126 {
      return false
    }
  }
  true
}

///|
fn validate_method_name(
  service : String,
  method_name : String,
) -> Result[Unit, RpcError] {
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
  if !is_ascii_visible_string(service) {
    return Err(
      invalid_argument_error("service must use ASCII visible characters"),
    )
  }
  if !is_ascii_visible_string(method_name) {
    return Err(
      invalid_argument_error("method must use ASCII visible characters"),
    )
  }
  Ok(())
}
