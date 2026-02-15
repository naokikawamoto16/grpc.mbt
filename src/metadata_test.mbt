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
test "Metadata key normalization and get" {
  let metadata = Metadata::new()
  ignore(metadata.add_text("X-Test", "v1"))
  let values = metadata.get("x-test")
  assert_eq(values, [Text("v1")])
}

///|
test "Metadata supports multi-value" {
  let metadata = Metadata::new()
  ignore(metadata.add_text("x-key", "a"))
  ignore(metadata.add_text("x-key", "b"))
  assert_eq(metadata.get("x-key"), [Text("a"), Text("b")])
}

///|
test "Metadata enforces -bin text restriction" {
  let metadata = Metadata::new()
  let result = metadata.add_text("trace-bin", "nope")
  assert_true(result is Err(_))
}

///|
test "Metadata enforces -bin binary restriction" {
  let metadata = Metadata::new()
  let result = metadata.add_binary("trace", b"abc")
  assert_true(result is Err(_))
}

///|
test "Metadata accepts valid binary key" {
  let metadata = Metadata::new()
  let payload = b"abc"
  ignore(metadata.add_binary("trace-bin", payload))
  assert_eq(metadata.get("trace-bin"), [Binary(payload)])
}

///|
test "Metadata rejects empty key" {
  let metadata = Metadata::new()
  assert_true(metadata.add_text("", "value") is Err(_))
}

///|
test "Metadata rejects key with invalid characters" {
  let metadata = Metadata::new()
  assert_true(metadata.add_text("x@key", "value") is Err(_))
  assert_true(metadata.add_text("x!key", "value") is Err(_))
  assert_true(metadata.add_text("x key", "value") is Err(_))
  assert_true(metadata.add_text("x#key", "value") is Err(_))
}

///|
test "Metadata accepts key with valid special characters" {
  let metadata = Metadata::new()
  assert_true(metadata.add_text("x_key", "value") is Ok(_))
  assert_true(metadata.add_text("x-key", "value") is Ok(_))
  assert_true(metadata.add_text("x.key", "value") is Ok(_))
  assert_true(metadata.add_text("x0key", "value") is Ok(_))
}

///|
test "Metadata rejects non-ASCII key" {
  let metadata = Metadata::new()
  assert_true(metadata.add_text("测试", "value") is Err(_))
  assert_true(metadata.add_text("🔑", "value") is Err(_))
  assert_true(metadata.add_text("klüft", "value") is Err(_))
}

///|
test "Metadata entries returns all stored entries" {
  let metadata = Metadata::new()
  ignore(metadata.add_text("x-a", "1"))
  ignore(metadata.add_text("x-b", "2"))
  let entries = metadata.entries()
  assert_eq(entries.length(), 2)
}
