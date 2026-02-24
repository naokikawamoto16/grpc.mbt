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
fn decode_fail(_ : Bytes) -> String raise {
  raise DecodeFail
}

///|
async test "backend_port new_channel accepts populated insecure options" {
  let server = @backend_test_util.BackendTest::start_test_server_insecure()
  let target = "127.0.0.1:\{server.port()}"
  let options : BackendChannelOptions = {
    security: Insecure,
    max_send_message_length: Some(1),
    max_receive_message_length: Some(2),
    keepalive_time_ms: Some(3),
    keepalive_timeout_ms: Some(4),
    default_authority: Some("authority.example"),
    user_agent: Some("grpc-test/1.0"),
  }
  let result = new_channel(target, options)

  match result {
    Ok(channel) => {
      let open_before_close = is_channel_closed(channel)
      server.stop()
      close_channel(channel)
      let closed_after_close = is_channel_closed(channel)
      close_channel(channel)
      assert_eq(open_before_close, false)
      assert_eq(closed_after_close, true)
    }
    Err(_) => {
      server.stop()
      panic()
    }
  }
}

///|
async test "backend_port new_channel accepts populated tls options" {
  let tls_material = @backend_test_util.BackendTest::generate_test_tls_material()
  let cert_chain = tls_material.0
  let private_key = tls_material.1
  let server = @backend_test_util.BackendTest::start_test_server_tls(
    cert_chain, private_key,
  )
  let target = "127.0.0.1:\{server.port()}"
  let options : BackendChannelOptions = {
    security: Tls({
      root_certs: Some(cert_chain),
      private_key: Some(private_key),
      cert_chain: Some(cert_chain),
      server_name_override: Some("localhost"),
      reject_unauthorized: Some(true),
    }),
    max_send_message_length: Some(10),
    max_receive_message_length: Some(20),
    keepalive_time_ms: Some(30),
    keepalive_timeout_ms: Some(40),
    default_authority: Some("localhost"),
    user_agent: Some("grpc-test/2.0"),
  }
  let result = new_channel(target, options)

  match result {
    Ok(channel) => {
      let open_before_close = is_channel_closed(channel)
      server.stop()
      close_channel(channel)
      let closed_after_close = is_channel_closed(channel)
      close_channel(channel)
      assert_eq(open_before_close, false)
      assert_eq(closed_after_close, true)
    }
    Err(_) => {
      server.stop()
      panic()
    }
  }
}

///|
async test "backend_port unary cancel is idempotent" {
  let server = @backend_test_util.BackendTest::start_test_server_insecure()
  let target = "127.0.0.1:\{server.port()}"
  let channel_result = new_channel(target, insecure_channel_options_for_test())

  match channel_result {
    Err(_) => {
      server.stop()
      panic()
    }
    Ok(channel) => {
      let start_result = start_unary(
        channel,
        "/test.EchoService/Echo",
        "sleep:5000:done",
        text => @utf8.encode(text),
        bytes => @utf8.decode(bytes),
        call_options_for_test(),
      )
      match start_result {
        Err(_) => {
          close_channel(channel)
          server.stop()
          panic()
        }
        Ok(cancel_call) => {
          let done_before_cancel = is_unary_done(cancel_call)
          cancel_unary(cancel_call)
          cancel_unary(cancel_call)
          let cancelled = await_unary(cancel_call)
          close_channel(channel)
          server.stop()

          assert_eq(done_before_cancel, false)
          match cancelled {
            Ok(_) => panic()
            Err(error) => {
              assert_eq(error.code, 1)
              assert_eq(error.kind, Cancelled)
            }
          }
        }
      }
    }
  }
}

///|
async test "backend_port unary codec decode failure is normalized" {
  let server = @backend_test_util.BackendTest::start_test_server_insecure()
  let target = "127.0.0.1:\{server.port()}"
  let channel_result = new_channel(target, insecure_channel_options_for_test())

  match channel_result {
    Err(_) => {
      server.stop()
      panic()
    }
    Ok(channel) => {
      let start_result = start_unary(
        channel,
        "/test.EchoService/Echo",
        "hello",
        text => @utf8.encode(text),
        decode_fail,
        call_options_for_test(),
      )
      match start_result {
        Err(_) => {
          close_channel(channel)
          server.stop()
          panic()
        }
        Ok(call) => {
          let decoded = await_unary(call)
          close_channel(channel)
          server.stop()

          match decoded {
            Ok(_) => panic()
            Err(error) => {
              assert_eq(error.code, 13)
              assert_eq(error.kind, CodecDecode)
              assert_eq(error.message, "codec decode failed")
              assert_true(error.details is Some(_))
              assert_eq(error.metadata_text, [])
              assert_eq(error.metadata_binary, [])
            }
          }
        }
      }
    }
  }
}

///|
async test "backend_port unary forwards text and binary metadata values" {
  let server = @backend_test_util.BackendTest::start_test_server_insecure()
  let target = "127.0.0.1:\{server.port()}"
  let channel_result = new_channel(target, insecure_channel_options_for_test())

  match channel_result {
    Err(_) => {
      server.stop()
      panic()
    }
    Ok(channel) => {
      let start_result = start_unary(
        channel,
        "/test.EchoService/Echo",
        "metadata:echo",
        text => @utf8.encode(text),
        bytes => @utf8.decode(bytes),
        call_options_with_metadata_for_test(),
      )
      match start_result {
        Err(_) => {
          close_channel(channel)
          server.stop()
          panic()
        }
        Ok(call) => {
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
      }
    }
  }
}

///|
async test "backend_port await_unary caches result for sequential calls" {
  let server = @backend_test_util.BackendTest::start_test_server_insecure()
  let target = "127.0.0.1:\{server.port()}"
  let channel_result = new_channel(target, insecure_channel_options_for_test())

  match channel_result {
    Err(_) => {
      server.stop()
      panic()
    }
    Ok(channel) => {
      let mut decode_calls = 0
      let start_result = start_unary(
        channel,
        "/test.EchoService/Echo",
        "cached",
        text => @utf8.encode(text),
        bytes => {
          decode_calls = decode_calls + 1
          if decode_calls > 1 {
            raise DecodeFail
          }
          @utf8.decode(bytes)
        },
        call_options_for_test(),
      )
      match start_result {
        Err(_) => {
          close_channel(channel)
          server.stop()
          panic()
        }
        Ok(call) => {
          let first = await_unary(call)
          let second = await_unary(call)
          close_channel(channel)
          server.stop()

          assert_eq(first, Ok("cached"))
          assert_eq(second, Ok("cached"))
          assert_eq(decode_calls, 1)
        }
      }
    }
  }
}

///|
async test "backend_port await_unary rejects concurrent waits" {
  let server = @backend_test_util.BackendTest::start_test_server_insecure()
  let target = "127.0.0.1:\{server.port()}"
  let channel_result = new_channel(target, insecure_channel_options_for_test())

  match channel_result {
    Err(_) => {
      server.stop()
      panic()
    }
    Ok(channel) => {
      let start_result = start_unary(
        channel,
        "/test.EchoService/Echo",
        "sleep:50:done",
        text => @utf8.encode(text),
        bytes => @utf8.decode(bytes),
        call_options_for_test(),
      )
      match start_result {
        Err(_) => {
          close_channel(channel)
          server.stop()
          panic()
        }
        Ok(call) => {
          let waits : Array[async () -> Result[String, BackendError]] = [
            () => await_unary(call),
            () => await_unary(call),
          ]
          let results = @async.all(waits)
          close_channel(channel)
          server.stop()

          let success_count = results
            .filter(result => result == Ok("done"))
            .length()
          let concurrent_errors = results.filter(result => {
            match result {
              Err(error) =>
                error.kind == InvalidUsage &&
                error.message == "concurrent unary wait is not supported"
              Ok(_) => false
            }
          })
          assert_eq(success_count, 1)
          assert_eq(concurrent_errors.length(), 1)
        }
      }
    }
  }
}
