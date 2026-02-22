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
/// Path to the grpc-js backend FFI source file.
let ffi_source_path : String = "src/internal/backend_grpc_js/ffi_grpc_js.mbt"

///|
fn find_or_panic(text : String, needle : String) -> Int {
  match text.find(needle) {
    Some(index) => index
    None => panic()
  }
}

///|
fn slice_from(text : String, start_marker : String) -> String {
  let start = find_or_panic(text, start_marker)
  text.unsafe_substring(start~, end=text.length())
}

///|
fn slice_block(text : String, start_marker : String) -> String {
  let tail = slice_from(text, start_marker)
  match tail.find("\n///|") {
    Some(end) => tail.unsafe_substring(start=0, end~)
    None => tail
  }
}

///|
/// Verify that generic codec functions do not leak into the extern boundary.
///
/// MoonBit extern functions cannot be generic, so the adapter layer must
/// encode/decode on the MoonBit side and pass raw `Bytes` across the FFI.
async test "Codec generics stay out of extern boundary" {
  let ffi_source = @test_util.BackendTest::read_text_file(ffi_source_path)
  let ffi_start_unary_block = slice_block(
    ffi_source, "extern \"js\" fn ffi_start_unary(",
  )
  assert_true(ffi_start_unary_block.contains("request : Bytes"))
  assert_true(
    !ffi_source.contains("extern \"js\" fn ffi_start_unary_with_codec("),
  )
  assert_true(
    !ffi_source.contains("extern \"js\" fn ffi_await_unary_with_codec("),
  )
}

///|
/// Verify wait_for_ready is wired through metadata options expected by grpc-js.
async test "wait_for_ready is passed via metadata options" {
  let ffi_source = @test_util.BackendTest::read_text_file(ffi_source_path)
  let ffi_start_unary_block = slice_block(
    ffi_source, "extern \"js\" fn ffi_start_unary(",
  )
  assert_true(ffi_start_unary_block.contains("metadata.setOptions("))
  assert_true(ffi_start_unary_block.contains("waitForReady: true"))
  assert_true(
    !ffi_start_unary_block.contains("callOptions.waitForReady = true"),
  )
}

///|
/// Verify reject_unauthorized is passed to createSsl verifyOptions.
async test "reject_unauthorized is passed via createSsl verifyOptions" {
  let ffi_source = @test_util.BackendTest::read_text_file(ffi_source_path)
  let ffi_new_channel_block = slice_block(
    ffi_source, "extern \"js\" fn ffi_new_channel(",
  )
  assert_true(
    ffi_new_channel_block.contains(
      "rejectUnauthorized: Boolean(reject_unauthorized)",
    ),
  )
  assert_true(ffi_new_channel_block.contains("createSsl("))
  assert_true(ffi_new_channel_block.contains("fromBytes(cert_chain),"))
  assert_true(ffi_new_channel_block.contains("verifyOptions,"))
  assert_true(
    !ffi_new_channel_block.contains("grpc-node.tls_reject_unauthorized"),
  )
}

///|
/// Verify status code -> kind canonicalization stays in MoonBit bridge layer.
async test "ffi normalizeError does not duplicate kind canonicalization" {
  let ffi_source = @test_util.BackendTest::read_text_file(ffi_source_path)
  let ffi_start_unary_block = slice_block(
    ffi_source, "extern \"js\" fn ffi_start_unary(",
  )
  assert_true(ffi_start_unary_block.contains("const normalizeError = ("))
  assert_true(ffi_start_unary_block.contains("kindHint || \"status\""))
  assert_true(!ffi_start_unary_block.contains("code === grpc.status.CANCELLED"))
  assert_true(
    !ffi_start_unary_block.contains("code === grpc.status.DEADLINE_EXCEEDED"),
  )
}

///|
/// Verify unary wait handles already-aborted signals and cleans up listeners.
async test "waitWithSignal handles pre-aborted signal" {
  let ffi_source = @test_util.BackendTest::read_text_file(ffi_source_path)
  let ffi_start_unary_block = slice_block(
    ffi_source, "extern \"js\" fn ffi_start_unary(",
  )
  assert_true(ffi_start_unary_block.contains("signal && signal.aborted"))
  assert_true(ffi_start_unary_block.contains("signal.removeEventListener"))
}
