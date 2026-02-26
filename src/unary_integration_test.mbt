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
  @async.with_task_group(root => {
    let server = @backend_test_util.BackendTest::start_test_server_insecure()
    defer root.spawn_bg(allow_failure=true, () => server.stop())
    let channel = Channel::new("127.0.0.1:\{server.port()}").unwrap()
    defer channel.close()
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
  })
}

///|
async test "TLS unary" {
  @async.with_task_group(root => {
    let tls_material = @backend_test_util.BackendTest::generate_test_tls_material()
    let cert = tls_material.0
    let key = tls_material.1
    let server = @backend_test_util.BackendTest::start_test_server_tls(
      cert, key,
    )
    defer root.spawn_bg(allow_failure=true, () => server.stop())
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
    defer channel.close()
    let client = Client::new(channel)
    let descriptor = MethodDescriptor::new(
      "test.EchoService",
      "Echo",
      utf8_codec(),
    ).unwrap()
    let result = client.unary(descriptor, "tls")
    assert_eq(result, Ok("tls"))
  })
}

///|
async test "TLS unary with reject_unauthorized=false allows self-signed server without roots" {
  @async.with_task_group(root => {
    let tls_material = @backend_test_util.BackendTest::generate_test_tls_material()
    let cert = tls_material.0
    let key = tls_material.1
    let server = @backend_test_util.BackendTest::start_test_server_tls(
      cert, key,
    )
    defer root.spawn_bg(allow_failure=true, () => server.stop())
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
    defer channel.close()
    let client = Client::new(channel)
    let descriptor = MethodDescriptor::new(
      "test.EchoService",
      "Echo",
      utf8_codec(),
    ).unwrap()
    let result = client.unary(descriptor, "tls-no-verify")
    assert_eq(result, Ok("tls-no-verify"))
  })
}

///|
async test "Bytes/Buffer performance smoke" {
  @async.with_task_group(root => {
    let server = @backend_test_util.BackendTest::start_test_server_insecure()
    defer root.spawn_bg(allow_failure=true, () => server.stop())
    let channel = Channel::new("127.0.0.1:\{server.port()}").unwrap()
    defer channel.close()
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
  })
}

///|
async test "Close racing with pending unary keeps terminal state consistent" {
  @async.with_task_group(root => {
    let server = @backend_test_util.BackendTest::start_test_server_insecure()
    defer root.spawn_bg(allow_failure=true, () => server.stop())
    let channel = Channel::new("127.0.0.1:\{server.port()}").unwrap()
    defer channel.close()
    let client = Client::new(channel)
    let descriptor = MethodDescriptor::new(
      "test.EchoService",
      "Echo",
      utf8_codec(),
    ).unwrap()
    let call = client.start_unary(descriptor, "sleep:200:after-close")
    @async.sleep(20)
    assert_true(!call.is_done())
    channel.close()
    let result = call.wait()
    match result {
      Ok(_) => panic()
      Err(error) =>
        assert_true(error.kind == Cancelled || error.kind == ChannelClosed)
    }
  })
}

///|
async test "Unary forwards text and binary metadata values" {
  @async.with_task_group(root => {
    let server = @backend_test_util.BackendTest::start_test_server_insecure()
    defer root.spawn_bg(allow_failure=true, () => server.stop())
    let channel = Channel::new("127.0.0.1:\{server.port()}").unwrap()
    defer channel.close()
    let client = Client::new(channel)
    let descriptor = MethodDescriptor::new(
      "test.EchoService",
      "Echo",
      utf8_codec(),
    ).unwrap()
    let metadata = Metadata::new()
    assert_eq(metadata.add_text("x-request-id", "req-1"), Ok(()))
    assert_eq(metadata.add_text("x-request-id", "req-2"), Ok(()))
    assert_eq(metadata.add_text("x-tag", "alpha"), Ok(()))
    assert_eq(metadata.add_text("x-request-id", "req-3"), Ok(()))
    assert_eq(metadata.add_binary("trace-bin", b"\x01\x02"), Ok(()))
    assert_eq(metadata.add_binary("trace-bin", b"\x03"), Ok(()))
    assert_eq(metadata.add_binary("trace-bin", b"\x04\x05"), Ok(()))
    let options : CallOptions = {
      metadata,
      timeout_ms: None,
      wait_for_ready: false,
    }

    let result = client.unary(descriptor, "metadata:echo", options~)

    match result {
      Ok(response) =>
        assert_eq(
          response, "x-request-id=req-1, req-2, req-3;x-tag=alpha;x-empty=;trace-bin=0102,03,0405;empty-bin=",
        )
      Err(_) => panic()
    }
  })
}

///|
async test "wait_for_ready on unreachable target returns deadline exceeded timeout" {
  @async.with_task_group(root => {
    // Keep the same task-group structure as other async integration tests even though
    // this case does not spawn background tasks.
    let seeded = @backend_test_util.BackendTest::start_test_server_insecure()
    let dead_port = seeded.port()
    seeded.stop()

    let channel = Channel::new("127.0.0.1:\{dead_port}").unwrap()
    defer channel.close()
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
    // Suppress the unused warning because `root` is only kept for structural consistency.
    ignore(root)
  })
}
