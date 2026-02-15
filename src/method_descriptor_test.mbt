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
test "MethodDescriptor::new valid" {
  let result = MethodDescriptor::new("test.EchoService", "Echo", bytes_codec())
  assert_true(result is Ok(_))
  let descriptor = result.unwrap()
  assert_eq(descriptor.path, "/test.EchoService/Echo")
}

///|
test "MethodDescriptor::new rejects empty service" {
  let result = MethodDescriptor::new("", "Echo", bytes_codec())
  match result {
    Ok(_) => panic()
    Err(err) => {
      assert_eq(err.code, InvalidArgument)
      assert_eq(err.kind, InvalidArgument)
    }
  }
}

///|
test "MethodDescriptor::new rejects slash" {
  let result = MethodDescriptor::new("test/Service", "Echo", bytes_codec())
  match result {
    Ok(_) => panic()
    Err(err) => {
      assert_eq(err.code, InvalidArgument)
      assert_eq(err.kind, InvalidArgument)
    }
  }
}

///|
test "MethodDescriptor::new rejects non-ascii" {
  let result = MethodDescriptor::new("测试", "Echo", bytes_codec())
  match result {
    Ok(_) => panic()
    Err(err) => {
      assert_eq(err.code, InvalidArgument)
      assert_eq(err.kind, InvalidArgument)
    }
  }
}
