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
  assert_eq(metadata.add_text("X-Test", "v1"), Ok(()))
  let values = metadata.get("x-test")
  assert_eq(values, [Text("v1")])
}

///|
test "Metadata supports multi-value" {
  let metadata = Metadata::new()
  assert_eq(metadata.add_text("x-key", "a"), Ok(()))
  assert_eq(metadata.add_text("x-key", "b"), Ok(()))
  assert_eq(metadata.get("x-key"), [Text("a"), Text("b")])
}

///|
test "Metadata enforces -bin text restriction" {
  let metadata = Metadata::new()
  let result = metadata.add_text("trace-bin", "nope")
  match result {
    Ok(_) => panic()
    Err(err) => {
      assert_eq(err.code, InvalidArgument)
      assert_eq(err.kind, InvalidArgument)
    }
  }
  assert_eq(metadata.get("trace-bin"), [])
}

///|
test "Metadata enforces -bin binary restriction" {
  let metadata = Metadata::new()
  let result = metadata.add_binary("trace", b"abc")
  match result {
    Ok(_) => panic()
    Err(err) => {
      assert_eq(err.code, InvalidArgument)
      assert_eq(err.kind, InvalidArgument)
    }
  }
  assert_eq(metadata.get("trace"), [])
}

///|
test "Metadata accepts valid binary key" {
  let metadata = Metadata::new()
  let payload = b"abc"
  assert_eq(metadata.add_binary("trace-bin", payload), Ok(()))
  assert_eq(metadata.get("trace-bin"), [Binary(payload)])
}

///|
test "Metadata get returns independent array for binary values" {
  let metadata = Metadata::new()
  assert_eq(metadata.add_binary("trace-bin", b"\x01\x02"), Ok(()))

  let values = metadata.get("trace-bin")
  values.push(Binary(b"\x03"))

  assert_eq(metadata.get("trace-bin"), [Binary(b"\x01\x02")])
}

///|
test "Metadata rejects empty key" {
  let metadata = Metadata::new()
  match metadata.add_text("", "value") {
    Ok(_) => panic()
    Err(err) => {
      assert_eq(err.code, InvalidArgument)
      assert_eq(err.kind, InvalidArgument)
    }
  }
  assert_eq(metadata.entries(), [])
}

///|
test "Metadata rejects key with invalid characters" {
  let metadata = Metadata::new()
  match metadata.add_text("x@key", "value") {
    Ok(_) => panic()
    Err(err) => {
      assert_eq(err.code, InvalidArgument)
      assert_eq(err.kind, InvalidArgument)
    }
  }
  assert_eq(metadata.entries(), [])
  match metadata.add_text("x!key", "value") {
    Ok(_) => panic()
    Err(err) => {
      assert_eq(err.code, InvalidArgument)
      assert_eq(err.kind, InvalidArgument)
    }
  }
  assert_eq(metadata.entries(), [])
  match metadata.add_text("x key", "value") {
    Ok(_) => panic()
    Err(err) => {
      assert_eq(err.code, InvalidArgument)
      assert_eq(err.kind, InvalidArgument)
    }
  }
  assert_eq(metadata.entries(), [])
  match metadata.add_text("x#key", "value") {
    Ok(_) => panic()
    Err(err) => {
      assert_eq(err.code, InvalidArgument)
      assert_eq(err.kind, InvalidArgument)
    }
  }
  assert_eq(metadata.entries(), [])
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
  match metadata.add_text("测试", "value") {
    Ok(_) => panic()
    Err(err) => {
      assert_eq(err.code, InvalidArgument)
      assert_eq(err.kind, InvalidArgument)
    }
  }
  assert_eq(metadata.entries(), [])
  match metadata.add_text("🔑", "value") {
    Ok(_) => panic()
    Err(err) => {
      assert_eq(err.code, InvalidArgument)
      assert_eq(err.kind, InvalidArgument)
    }
  }
  assert_eq(metadata.entries(), [])
  match metadata.add_text("klüft", "value") {
    Ok(_) => panic()
    Err(err) => {
      assert_eq(err.code, InvalidArgument)
      assert_eq(err.kind, InvalidArgument)
    }
  }
  assert_eq(metadata.entries(), [])
}

///|
test "Metadata entries returns all stored entries" {
  let metadata = Metadata::new()
  assert_eq(metadata.add_text("X-A", "1"), Ok(()))
  assert_eq(metadata.add_text("x-b", "2"), Ok(()))
  let entries = metadata.entries()
  assert_eq(entries.length(), 2)
  match entries {
    [("x-a", [Text("1")]), ("x-b", [Text("2")])] => ()
    [("x-b", [Text("2")]), ("x-a", [Text("1")])] => ()
    _ => panic()
  }
}

///|
test "Metadata entries returns independent arrays for binary values" {
  let metadata = Metadata::new()
  assert_eq(metadata.add_binary("trace-bin", b"\x01"), Ok(()))

  let entries = metadata.entries()
  match entries {
    [("trace-bin", values)] => values.push(Binary(b"\x02"))
    _ => panic()
  }

  assert_eq(metadata.get("trace-bin"), [Binary(b"\x01")])
}
