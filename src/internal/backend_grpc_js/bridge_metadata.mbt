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
fn flatten_text_metadata(
  entries : Array[(String, Array[String])],
) -> (Array[String], Array[String]) {
  let keys : Array[String] = []
  let values : Array[String] = []
  for _, entry in entries {
    let key = entry.0
    let texts = entry.1
    for text in texts {
      keys.push(key)
      values.push(text)
    }
  }
  (keys, values)
}

///|
fn flatten_binary_metadata(
  entries : Array[(String, Array[Bytes])],
) -> (Array[String], Array[Bytes]) {
  let keys : Array[String] = []
  let values : Array[Bytes] = []
  for _, entry in entries {
    let key = entry.0
    let binaries = entry.1
    for binary in binaries {
      keys.push(key)
      values.push(binary)
    }
  }
  (keys, values)
}
