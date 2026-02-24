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
/// Handle for a single unary RPC.
pub struct UnaryCall[Resp] {
  priv handle : @internal.UnaryHandle[Resp]?
  priv mut cached : Result[Resp, RpcError]?
}

///|
fn[Resp] new_failed_unary_call(error : RpcError) -> UnaryCall[Resp] {
  { handle: None, cached: Some(Err(error)) }
}

///|
fn[Resp] new_pending_unary_call(
  handle : @internal.UnaryHandle[Resp],
) -> UnaryCall[Resp] {
  { handle: Some(handle), cached: None }
}

///|
/// Request cancellation for the in-flight unary call.
/// This method is idempotent.
pub fn[Resp] UnaryCall::cancel(self : UnaryCall[Resp]) -> Unit {
  if self.cached is Some(_) {
    return
  }
  // When cached is None, handle is guaranteed to be Some by constructors.
  @internal.cancel_unary(self.handle.unwrap())
}

///|
/// Returns `true` when the call has reached a terminal state.
pub fn[Resp] UnaryCall::is_done(self : UnaryCall[Resp]) -> Bool {
  if self.cached is Some(_) {
    return true
  }
  // When cached is None, handle is guaranteed to be Some by constructors.
  @internal.is_unary_done(self.handle.unwrap())
}

///|
/// Wait for unary completion and return the final result.
/// Repeated sequential calls return the same cached result.
/// Concurrent waits on the same `UnaryCall` are not supported.
pub async fn[Resp] UnaryCall::wait(
  self : UnaryCall[Resp],
) -> Result[Resp, RpcError] {
  if self.cached is Some(result) {
    return result
  }
  // When cached is None, handle is guaranteed to be Some by constructors.
  let handle = self.handle.unwrap()
  let result = @internal.await_unary(handle).map_err(error => {
    normalize_backend_error(error)
  })
  self.cached = Some(result)
  result
}
