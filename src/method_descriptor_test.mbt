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
fn bytes_codec() -> Codec[Bytes, Bytes] {
  { encode: bytes => bytes, decode: bytes => bytes }
}

///|
fn assert_invalid_argument_method_descriptor(
  result : Result[MethodDescriptor[Bytes, Bytes], RpcError],
) -> Unit raise {
  match result {
    Ok(_) => panic()
    Err(err) => {
      assert_eq(err.code, InvalidArgument)
      assert_eq(err.kind, InvalidArgument)
    }
  }
}

///|
test "MethodDescriptor::new valid" {
  let result = MethodDescriptor::new("test.EchoService", "Echo", bytes_codec())
  assert_true(result is Ok(_))
  let descriptor = result.unwrap()
  assert_eq(descriptor.path(), "/test.EchoService/Echo")
}

///|
test "MethodDescriptor::new valid proto-style names" {
  let result = MethodDescriptor::new(
    "test.v1.EchoService",
    "Echo_1",
    bytes_codec(),
  )
  assert_true(result is Ok(_))
  let descriptor = result.unwrap()
  assert_eq(descriptor.path(), "/test.v1.EchoService/Echo_1")
}

///|
test "MethodDescriptor::new rejects empty service" {
  let result = MethodDescriptor::new("", "Echo", bytes_codec())
  assert_invalid_argument_method_descriptor(result)
}

///|
test "MethodDescriptor::new rejects slash in service" {
  let result = MethodDescriptor::new("test/Service", "Echo", bytes_codec())
  assert_invalid_argument_method_descriptor(result)
}

///|
test "MethodDescriptor::new rejects non-ascii service" {
  let result = MethodDescriptor::new("测试", "Echo", bytes_codec())
  assert_invalid_argument_method_descriptor(result)
}

///|
test "MethodDescriptor::new rejects reserved character in service" {
  let result = MethodDescriptor::new("test.EchoService?", "Echo", bytes_codec())
  assert_invalid_argument_method_descriptor(result)
}

///|
test "MethodDescriptor::new rejects service segment starting with digit" {
  let result = MethodDescriptor::new("1test.EchoService", "Echo", bytes_codec())
  assert_invalid_argument_method_descriptor(result)
}

///|
test "MethodDescriptor::new rejects empty service segment" {
  let result = MethodDescriptor::new("test..EchoService", "Echo", bytes_codec())
  assert_invalid_argument_method_descriptor(result)
}

///|
test "MethodDescriptor::new rejects trailing dot in service" {
  let result = MethodDescriptor::new("test.EchoService.", "Echo", bytes_codec())
  assert_invalid_argument_method_descriptor(result)
}

///|
test "MethodDescriptor::new rejects empty method" {
  let result = MethodDescriptor::new("test.EchoService", "", bytes_codec())
  assert_invalid_argument_method_descriptor(result)
}

///|
test "MethodDescriptor::new rejects slash in method" {
  let result = MethodDescriptor::new("test.EchoService", "Ec/ho", bytes_codec())
  assert_invalid_argument_method_descriptor(result)
}

///|
test "MethodDescriptor::new rejects non-ascii method" {
  let result = MethodDescriptor::new(
    "test.EchoService",
    "测试",
    bytes_codec(),
  )
  assert_invalid_argument_method_descriptor(result)
}

///|
test "MethodDescriptor::new rejects reserved character in method" {
  let result = MethodDescriptor::new(
    "test.EchoService",
    "Echo#1",
    bytes_codec(),
  )
  assert_invalid_argument_method_descriptor(result)
}

///|
test "MethodDescriptor::new rejects method starting with digit" {
  let result = MethodDescriptor::new("test.EchoService", "1Echo", bytes_codec())
  assert_invalid_argument_method_descriptor(result)
}

///|
test "MethodDescriptor::new rejects hyphen in method" {
  let result = MethodDescriptor::new(
    "test.EchoService",
    "Echo-Method",
    bytes_codec(),
  )
  assert_invalid_argument_method_descriptor(result)
}

///|
test "MethodDescriptor::new rejects dot in method" {
  let result = MethodDescriptor::new(
    "test.EchoService",
    "Echo.Method",
    bytes_codec(),
  )
  assert_invalid_argument_method_descriptor(result)
}
