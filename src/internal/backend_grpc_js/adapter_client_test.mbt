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
let adapter_client_source_path : String = "src/internal/backend_grpc_js/adapter_client.mbt"

///|
fn raw_channel_options_for_test() -> RawChannelOptions {
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
fn raw_call_options_for_test() -> RawCallOptions {
  {
    metadata_text: [],
    metadata_binary: [],
    timeout_ms: None,
    wait_for_ready: false,
  }
}

///|
fn encode_fail(_ : String) -> Bytes raise {
  raise EncodeFail
}

///|
async test "start_unary catches synchronous ffi_start_unary exceptions" {
  let source = @test_util.BackendTest::read_text_file(
    adapter_client_source_path,
  )
  assert_true(source.contains("ffi_start_unary_result_is_ok(started)"))
  assert_true(source.contains("ffi_start_unary_result_error(started)"))
}

///|
async test "start_unary_with_codec normalizes codec encode failure" {
  let channel = new_channel("127.0.0.1:50051", raw_channel_options_for_test()).unwrap()
  let result = start_unary_with_codec(
    channel,
    "/test.EchoService/Echo",
    "ignored",
    encode_fail,
    raw_call_options_for_test(),
  )
  match result {
    Ok(_) => panic()
    Err(error) => {
      assert_eq(error.code, 13)
      assert_eq(error.kind, "codec_encode")
      assert_eq(error.message, "codec encode failed")
    }
  }
  close_channel(channel)
}
