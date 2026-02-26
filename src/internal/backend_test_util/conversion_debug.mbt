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
pub(all) struct ConversionCounters {
  bytes_to_buffer : Int
  buffer_to_bytes : Int
} derive(Show, Eq, ToJson)

///|
pub fn BackendTest::reset_conversion_counters() -> Unit {
  ffi_reset_conversion_counters()
}

///|
pub fn BackendTest::conversion_counters() -> ConversionCounters {
  let values = ffi_get_conversion_counters()
  if values.length() != 2 {
    abort("ffi_get_conversion_counters must return exactly 2 items")
  }
  { bytes_to_buffer: values[0], buffer_to_bytes: values[1] }
}
