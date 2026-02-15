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
fn default_channel_options_for_test() -> RawChannelOptions {
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
fn to_impl_channel_options_for_test(
  options : RawChannelOptions,
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
fn default_call_options_for_test() -> RawCallOptions {
  {
    metadata_text: [],
    metadata_binary: [],
    timeout_ms: None,
    wait_for_ready: false,
  }
}

///|
fn decode_fail(_ : Bytes) -> String raise {
  raise DecodeFail
}

///|
async test "Facade new_channel delegates Ok/Err to implementation" {
  @async.sleep(0)
  let server = @impl.start_test_server_insecure()
  let target = "127.0.0.1:\{server.port()}"
  let options = default_channel_options_for_test()
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
    (Err(lhs), Err(rhs)) => assert_eq(lhs, rhs)
    _ => panic()
  }

  server.stop()
}

///|
async test "Facade unary keeps cancel idempotency and codec decode normalization" {
  @async.sleep(0)
  let server = @impl.start_test_server_insecure()
  let target = "127.0.0.1:\{server.port()}"
  let channel = new_channel(target, default_channel_options_for_test()).unwrap()
  let call_options = default_call_options_for_test()

  let cancel_call = start_unary_with_codec(
    channel,
    "/test.EchoService/Echo",
    "sleep:200:done",
    text => @utf8.encode(text),
    call_options,
  ).unwrap()
  cancel_unary(cancel_call)
  cancel_unary(cancel_call)
  let cancelled = await_unary_with_codec(cancel_call, bytes => {
    @utf8.decode(bytes)
  })
  match cancelled {
    Ok(_) => panic()
    Err(error) => assert_eq(error.kind, Cancelled)
  }

  let decode_call = start_unary_with_codec(
    channel,
    "/test.EchoService/Echo",
    "hello",
    text => @utf8.encode(text),
    call_options,
  ).unwrap()
  let decoded = await_unary_with_codec(decode_call, decode_fail)
  match decoded {
    Ok(_) => panic()
    Err(error) => assert_eq(error.kind, CodecDecode)
  }

  close_channel(channel)
  server.stop()
}

///|
test "Capabilities expose current unary-only support" {
  let caps = capabilities()
  assert_true(caps.unary)
  assert_true(!caps.server_streaming)
  assert_true(!caps.client_streaming)
  assert_true(!caps.bidi_streaming)
}
