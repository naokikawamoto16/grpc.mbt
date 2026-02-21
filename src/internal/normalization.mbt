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
/// gRPC INTERNAL status code (13) used as the default for locally generated errors.
let internal_status_code : Int = 13

///|
fn from_raw_error(raw : @impl.RawError) -> BackendError {
  {
    code: raw.code,
    message: raw.message,
    details: raw.details,
    metadata_text: raw.metadata_text,
    metadata_binary: raw.metadata_binary,
    kind: raw.kind,
  }
}

///|
fn message_error(message : String, kind? : String) -> BackendError {
  {
    code: internal_status_code,
    message,
    details: None,
    metadata_text: [],
    metadata_binary: [],
    kind: kind.unwrap_or("internal"),
  }
}
