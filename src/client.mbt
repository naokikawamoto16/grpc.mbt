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
/// A thin RPC caller bound to a shared channel.
pub struct Client {
  priv channel : Channel
}

///|
/// Create a new client over the given channel.
pub fn Client::new(channel : Channel) -> Client {
  { channel, }
}

///|
/// Start a unary RPC and return an awaitable call handle.
/// The returned handle may already be failed when validation fails.
pub fn[Req, Resp] Client::start_unary(
  self : Client,
  desc : MethodDescriptor[Req, Resp],
  request : Req,
  options? : CallOptions = default_call_options(),
) -> UnaryCall[Resp] {
  if self.channel.is_closed() {
    return new_failed_unary_call(channel_closed_error(None))
  }
  match validate_timeout(options) {
    Err(error) => return new_failed_unary_call(error)
    Ok(_) => ()
  }

  match
    @internal.start_unary(
      self.channel.handle,
      desc.path,
      request,
      desc.codec.encode,
      desc.codec.decode,
      to_backend_call_options(options),
    ) {
    Ok(handle) => new_pending_unary_call(handle)
    Err(error) => new_failed_unary_call(normalize_backend_error(error))
  }
}

///|
/// Call a unary RPC and await its completion.
/// Equivalent to `start_unary(...).wait()`.
pub async fn[Req, Resp] Client::unary(
  self : Client,
  desc : MethodDescriptor[Req, Resp],
  request : Req,
  options? : CallOptions = default_call_options(),
) -> Result[Resp, RpcError] {
  self.start_unary(desc, request, options~).wait()
}

///|
fn to_backend_call_options(
  options : CallOptions,
) -> @internal.BackendCallOptions {
  let metadata_pairs = metadata_to_backend(options.metadata)
  {
    metadata_text: metadata_pairs.0,
    metadata_binary: metadata_pairs.1,
    timeout_ms: options.timeout_ms,
    wait_for_ready: options.wait_for_ready,
  }
}

///|
fn validate_timeout(options : CallOptions) -> Result[Unit, RpcError] {
  match options.timeout_ms {
    Some(timeout_ms) if timeout_ms <= 0 =>
      Err(invalid_argument_error("timeout_ms must be a positive integer"))
    _ => Ok(())
  }
}
