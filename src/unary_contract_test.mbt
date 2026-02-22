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
suberror EncodeFail

///|
suberror DecodeFail

///|
fn utf8_codec() -> Codec[String, String] {
  { encode: text => @utf8.encode(text), decode: bytes => @utf8.decode(bytes) }
}

///|
fn encode_fail_codec() -> Codec[String, String] {
  { encode: _ => raise EncodeFail, decode: bytes => @utf8.decode(bytes) }
}

///|
fn decode_fail_codec() -> Codec[String, String] {
  { encode: text => @utf8.encode(text), decode: _ => raise DecodeFail }
}

///|
fn default_call_options_for_test(timeout_ms : Int?) -> CallOptions {
  { metadata: Metadata::new(), timeout_ms, wait_for_ready: false }
}

///|
async fn new_insecure_client() -> (
  Client,
  Channel,
  @backend_test_util.TestServer,
) {
  let server = @backend_test_util.BackendTest::start_test_server_insecure()
  let target = "127.0.0.1:\{server.port()}"
  let channel = Channel::new(target).unwrap()
  (Client::new(channel), channel, server)
}

///|
async test "Unary success and status mapping" {
  let setup = new_insecure_client()
  let client = setup.0
  let channel = setup.1
  let server = setup.2
  let descriptor = MethodDescriptor::new(
    "test.EchoService",
    "Echo",
    utf8_codec(),
  ).unwrap()
  let success = client.unary(descriptor, "hello")
  assert_eq(success, Ok("hello"))

  let failed = client.unary(descriptor, "error:3:bad request")
  match failed {
    Ok(_) => panic()
    Err(err) => {
      assert_eq(err.code, InvalidArgument)
      assert_eq(err.kind, Status)
      assert_eq(err.details, Some("bad request"))
      assert_eq(err.metadata.get("x-error-source"), [Text("test-server")])
      assert_eq(err.metadata.get("trace-bin"), [Binary(b"\x01\x02\x03\x04")])
    }
  }
  channel.close()
  server.stop()
}

///|
async test "Unary timeout and timeout argument validation" {
  let setup = new_insecure_client()
  let client = setup.0
  let channel = setup.1
  let server = setup.2
  let descriptor = MethodDescriptor::new(
    "test.EchoService",
    "Echo",
    utf8_codec(),
  ).unwrap()
  let timeout_result = client.unary(
    descriptor,
    "sleep:80:late",
    options=default_call_options_for_test(Some(10)),
  )
  match timeout_result {
    Ok(_) => panic()
    Err(err) => {
      assert_eq(err.code, DeadlineExceeded)
      assert_eq(err.kind, Timeout)
    }
  }

  let immediate = client.unary(
    descriptor,
    "hello",
    options=default_call_options_for_test(Some(0)),
  )
  match immediate {
    Ok(_) => panic()
    Err(err) => {
      assert_eq(err.code, InvalidArgument)
      assert_eq(err.kind, InvalidArgument)
    }
  }
  channel.close()
  server.stop()
}

///|
async test "Unary cancel idempotent and close gate" {
  let setup = new_insecure_client()
  let client = setup.0
  let channel = setup.1
  let server = setup.2
  let descriptor = MethodDescriptor::new(
    "test.EchoService",
    "Echo",
    utf8_codec(),
  ).unwrap()
  let call = client.start_unary(descriptor, "sleep:200:done")
  call.cancel()
  call.cancel()
  let cancelled = call.wait()
  match cancelled {
    Ok(_) => panic()
    Err(err) => assert_eq(err.code, Cancelled)
  }

  // close gate
  let target = "127.0.0.1:\{server.port()}"
  let close_gate_channel = Channel::new(target).unwrap()
  let close_client = Client::new(close_gate_channel)
  close_gate_channel.close()
  close_gate_channel.close()
  let after_close = close_client.unary(descriptor, "hello")
  match after_close {
    Ok(_) => panic()
    Err(err) => assert_eq(err.kind, ChannelClosed)
  }
  channel.close()
  server.stop()
}

///|
async test "Codec encode/decode failures are normalized" {
  let setup = new_insecure_client()
  let client = setup.0
  let channel = setup.1
  let server = setup.2

  let encode_fail_descriptor = MethodDescriptor::new(
    "test.EchoService",
    "Echo",
    encode_fail_codec(),
  ).unwrap()
  let encode_fail = client.unary(encode_fail_descriptor, "ignored")
  match encode_fail {
    Ok(_) => panic()
    Err(err) => assert_eq(err.kind, CodecEncode)
  }

  let decode_fail_descriptor = MethodDescriptor::new(
    "test.EchoService",
    "Echo",
    decode_fail_codec(),
  ).unwrap()
  let decode_fail = client.unary(decode_fail_descriptor, "hello")
  match decode_fail {
    Ok(_) => panic()
    Err(err) => assert_eq(err.kind, CodecDecode)
  }

  channel.close()
  server.stop()
}

///|
async test "Task cancellation normalizes to cancelled result" {
  let setup = new_insecure_client()
  let client = setup.0
  let channel = setup.1
  let server = setup.2
  let descriptor = MethodDescriptor::new(
    "test.EchoService",
    "Echo",
    utf8_codec(),
  ).unwrap()
  let call = client.start_unary(descriptor, "sleep:200:done")
  let timed = @async.with_timeout_opt(10, () => call.wait())
  match timed {
    Some(Ok(_)) => panic()
    Some(Err(err)) => assert_eq(err.kind, Cancelled)
    None => ()
  }
  let cancelled = call.wait()
  match cancelled {
    Ok(_) => panic()
    Err(err) => {
      assert_eq(err.code, Cancelled)
      assert_eq(err.kind, Cancelled)
    }
  }
  channel.close()
  server.stop()
}

///|
async test "Retry wait immediately after timeout does not return internal error" {
  let setup = new_insecure_client()
  let client = setup.0
  let channel = setup.1
  let server = setup.2
  let descriptor = MethodDescriptor::new(
    "test.EchoService",
    "Echo",
    utf8_codec(),
  ).unwrap()
  let call = client.start_unary(descriptor, "sleep:200:done")

  let timed = @async.with_timeout_opt(10, () => call.wait())
  assert_eq(timed, None)

  let retried = call.wait()
  match retried {
    Ok(_) => panic()
    Err(err) => {
      assert_true(err.kind != Internal)
      assert_eq(err.code, Cancelled)
      assert_eq(err.kind, Cancelled)
    }
  }

  channel.close()
  server.stop()
}

///|
async test "Unknown JS exception is normalized to RpcError" {
  let setup = new_insecure_client()
  let client = setup.0
  let channel = setup.1
  let server = setup.2
  @backend_test_util.BackendTest::inject_next_client_start_unary_exception()
  let descriptor : MethodDescriptor[String, String] = {
    service: "test.EchoService",
    method_name: "Echo",
    path: "/test.EchoService/Echo",
    codec: utf8_codec(),
  }
  let result = client.unary(descriptor, "hello")
  @backend_test_util.BackendTest::restore_client_start_unary_exception_injection()
  match result {
    Ok(_) => panic()
    Err(err) => {
      assert_eq(err.code, Internal)
      assert_eq(err.kind, Internal)
    }
  }
  channel.close()
  server.stop()
}
