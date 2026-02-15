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
pub fn reset_conversion_counters() -> Unit {
  @impl.reset_conversion_counters()
}

///|
pub fn conversion_counters() -> ConversionCounters {
  let counters = @impl.conversion_counters()
  {
    bytes_to_buffer: counters.bytes_to_buffer,
    buffer_to_bytes: counters.buffer_to_bytes,
  }
}
