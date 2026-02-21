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
async test "Insecure parallel unary" {
  let server = @backend_test_util.BackendTest::start_test_server_insecure()
  let channel = Channel::new("127.0.0.1:\{server.port()}").unwrap()
  let client = Client::new(channel)
  let descriptor = MethodDescriptor::new(
    "test.EchoService",
    "Echo",
    utf8_codec(),
  ).unwrap()

  let tasks : Array[async () -> Result[String, RpcError]] = [
    () => client.unary(descriptor, "a"),
    () => client.unary(descriptor, "b"),
    () => client.unary(descriptor, "c"),
  ]
  let results = @async.all(tasks)
  assert_eq(results, [Ok("a"), Ok("b"), Ok("c")])

  channel.close()
  server.stop()
}

///|
async test "TLS unary" {
  let tls_material = @backend_test_util.BackendTest::generate_test_tls_material()
  let cert = tls_material.0
  let key = tls_material.1
  let server = @backend_test_util.BackendTest::start_test_server_tls(cert, key)
  let options : ChannelOptions = {
    security: Tls({
      root_certs: Some(cert),
      private_key: None,
      cert_chain: None,
      server_name_override: Some("localhost"),
      reject_unauthorized: Some(true),
    }),
    max_send_message_length: None,
    max_receive_message_length: None,
    keepalive_time_ms: None,
    keepalive_timeout_ms: None,
    default_authority: None,
    user_agent: None,
  }
  let channel = Channel::new("127.0.0.1:\{server.port()}", options~).unwrap()
  let client = Client::new(channel)
  let descriptor = MethodDescriptor::new(
    "test.EchoService",
    "Echo",
    utf8_codec(),
  ).unwrap()
  let result = client.unary(descriptor, "tls")
  assert_eq(result, Ok("tls"))

  channel.close()
  server.stop()
}

///|
async test "TLS unary with reject_unauthorized=false allows self-signed server without roots" {
  let tls_material = @backend_test_util.BackendTest::generate_test_tls_material()
  let cert = tls_material.0
  let key = tls_material.1
  let server = @backend_test_util.BackendTest::start_test_server_tls(cert, key)
  let options : ChannelOptions = {
    security: Tls({
      root_certs: None,
      private_key: None,
      cert_chain: None,
      server_name_override: Some("localhost"),
      reject_unauthorized: Some(false),
    }),
    max_send_message_length: None,
    max_receive_message_length: None,
    keepalive_time_ms: None,
    keepalive_timeout_ms: None,
    default_authority: None,
    user_agent: None,
  }
  let channel = Channel::new("127.0.0.1:\{server.port()}", options~).unwrap()
  let client = Client::new(channel)
  let descriptor = MethodDescriptor::new(
    "test.EchoService",
    "Echo",
    utf8_codec(),
  ).unwrap()
  let result = client.unary(descriptor, "tls-no-verify")

  channel.close()
  server.stop()
  assert_eq(result, Ok("tls-no-verify"))
}

///|
async test "Bytes/Buffer performance smoke" {
  let server = @backend_test_util.BackendTest::start_test_server_insecure()
  let channel = Channel::new("127.0.0.1:\{server.port()}").unwrap()
  let client = Client::new(channel)
  let descriptor = MethodDescriptor::new(
    "test.EchoService",
    "Echo",
    bytes_codec(),
  ).unwrap()
  let payload = Bytes::make(256 * 1024, 97)

  @backend_test_util.BackendTest::reset_conversion_counters()
  let result = client.unary(descriptor, payload)
  let counters = @backend_test_util.BackendTest::conversion_counters()

  match result {
    Ok(response) => {
      assert_eq(response.length(), payload.length())
      assert_true(counters.bytes_to_buffer > 0)
      assert_true(counters.buffer_to_bytes > 0)
    }
    Err(_) => panic()
  }

  channel.close()
  server.stop()
}

///|
async test "Close during in-flight unary keeps terminal state consistent" {
  let server = @backend_test_util.BackendTest::start_test_server_insecure()
  let channel = Channel::new("127.0.0.1:\{server.port()}").unwrap()
  let client = Client::new(channel)
  let descriptor = MethodDescriptor::new(
    "test.EchoService",
    "Echo",
    utf8_codec(),
  ).unwrap()
  let call = client.start_unary(descriptor, "sleep:200:after-close")
  @async.sleep(20)
  channel.close()
  let result = call.wait()
  match result {
    Ok(_) => panic()
    Err(error) =>
      assert_true(error.kind == Cancelled || error.kind == ChannelClosed)
  }
  server.stop()
}

///|
async test "wait_for_ready delays transient unavailable until deadline" {
  let seeded = @backend_test_util.BackendTest::start_test_server_insecure()
  let dead_port = seeded.port()
  seeded.stop()

  let channel = Channel::new("127.0.0.1:\{dead_port}").unwrap()
  let client = Client::new(channel)
  let descriptor = MethodDescriptor::new(
    "test.EchoService",
    "Echo",
    utf8_codec(),
  ).unwrap()
  let options : CallOptions = {
    metadata: Metadata::new(),
    timeout_ms: Some(120),
    wait_for_ready: true,
  }
  let result = client.unary(descriptor, "hello", options~)
  match result {
    Ok(_) => panic()
    Err(err) => {
      assert_eq(err.code, DeadlineExceeded)
      assert_eq(err.kind, Timeout)
    }
  }
  channel.close()
}
