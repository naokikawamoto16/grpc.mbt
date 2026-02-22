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
suberror DecodeFail

///|
fn insecure_channel_options_for_test() -> BackendChannelOptions {
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
fn call_options_for_test() -> BackendCallOptions {
  {
    metadata_text: [],
    metadata_binary: [],
    timeout_ms: None,
    wait_for_ready: false,
  }
}

///|
fn call_options_with_metadata_for_test() -> BackendCallOptions {
  {
    metadata_text: [
      ("x-request-id", ["req-1", "req-2"]),
      ("x-empty", []),
      ("x-tag", ["alpha"]),
      ("x-request-id", ["req-3"]),
    ],
    metadata_binary: [
      ("trace-bin", [b"\x01\x02", b"\x03"]),
      ("empty-bin", []),
      ("trace-bin", [b"\x04\x05"]),
    ],
    timeout_ms: None,
    wait_for_ready: false,
  }
}

///|
fn to_impl_channel_options_for_test(
  options : BackendChannelOptions,
) -> @impl.RawChannelOptions {
  let security = match options.security {
    Insecure => @impl.Insecure
    Tls(raw_tls) =>
      @impl.Tls({
        root_certs: raw_tls.root_certs,
        private_key: raw_tls.private_key,
        cert_chain: raw_tls.cert_chain,
        server_name_override: raw_tls.server_name_override,
        reject_unauthorized: raw_tls.reject_unauthorized,
      })
  }
  {
    security,
    max_send_message_length: options.max_send_message_length,
    max_receive_message_length: options.max_receive_message_length,
    keepalive_time_ms: options.keepalive_time_ms,
    keepalive_timeout_ms: options.keepalive_timeout_ms,
    default_authority: options.default_authority,
    user_agent: options.user_agent,
  }
}

///|
fn decode_fail(_ : Bytes) -> String raise {
  raise DecodeFail
}

///|
async test "backend_port new_channel matches impl result shape" {
  let server = @backend_test_util.BackendTest::start_test_server_insecure()
  let target = "127.0.0.1:\{server.port()}"
  let options = insecure_channel_options_for_test()
  let facade = new_channel(target, options)
  let direct = @impl.new_channel(
    target,
    to_impl_channel_options_for_test(options),
  )

  match (facade, direct) {
    (Ok(channel), Ok(raw_channel)) => {
      assert_eq(is_channel_closed(channel), false)
      assert_eq(@impl.is_channel_closed(raw_channel), false)
      close_channel(channel)
      @impl.close_channel(raw_channel)
    }
    (Err(lhs), Err(rhs)) => {
      assert_eq(lhs.kind, "transport")
      assert_eq(lhs.message, rhs)
    }
    _ => panic()
  }

  server.stop()
}

///|
async test "backend_port unary keeps cancel idempotency and codec decode normalization" {
  let server = @backend_test_util.BackendTest::start_test_server_insecure()
  let target = "127.0.0.1:\{server.port()}"
  let channel = new_channel(target, insecure_channel_options_for_test()).unwrap()
  let call_options = call_options_for_test()

  let cancel_call = start_unary(
    channel,
    "/test.EchoService/Echo",
    "sleep:200:done",
    text => @utf8.encode(text),
    bytes => @utf8.decode(bytes),
    call_options,
  ).unwrap()
  cancel_unary(cancel_call)
  cancel_unary(cancel_call)
  let cancelled = await_unary(cancel_call)
  match cancelled {
    Ok(_) => panic()
    Err(error) => assert_eq(error.kind, "cancelled")
  }

  let decode_call = start_unary(
    channel,
    "/test.EchoService/Echo",
    "hello",
    text => @utf8.encode(text),
    decode_fail,
    call_options,
  ).unwrap()
  let decoded = await_unary(decode_call)
  match decoded {
    Ok(_) => panic()
    Err(error) => assert_eq(error.kind, "codec_decode")
  }

  close_channel(channel)
  server.stop()
}

///|
async test "backend_port unary forwards text and binary metadata values" {
  let server = @backend_test_util.BackendTest::start_test_server_insecure()
  let target = "127.0.0.1:\{server.port()}"
  let channel = new_channel(target, insecure_channel_options_for_test()).unwrap()
  let call = start_unary(
    channel,
    "/test.EchoService/Echo",
    "metadata:echo",
    text => @utf8.encode(text),
    bytes => @utf8.decode(bytes),
    call_options_with_metadata_for_test(),
  ).unwrap()

  let result = await_unary(call)
  close_channel(channel)
  server.stop()

  match result {
    Ok(response) =>
      assert_eq(
        response, "x-request-id=req-1, req-2, req-3;x-tag=alpha;x-empty=;trace-bin=0102,03,0405;empty-bin=",
      )
    Err(_) => panic()
  }
}
