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
pub(all) struct RawError {
  code : Int
  message : String
  details : String?
  metadata_text : Array[(String, Array[String])]
  metadata_binary : Array[(String, Array[Bytes])]
  kind : String
} derive(Show, Eq, ToJson)

///|
pub(all) enum RawUnaryOutcome {
  Success(Bytes)
  Failure(RawError)
} derive(Show, Eq, ToJson)

///|
fn from_js_outcome(outcome : JsUnaryOutcome) -> RawUnaryOutcome {
  if ffi_outcome_is_ok(outcome) {
    Success(ffi_outcome_response(outcome))
  } else {
    let code = ffi_outcome_error_code(outcome)
    let kind = normalize_raw_kind(ffi_outcome_error_kind(outcome), code)
    Failure({
      code,
      message: ffi_outcome_error_message(outcome),
      details: ffi_outcome_error_details(outcome),
      metadata_text: ffi_outcome_error_text_entries(outcome),
      metadata_binary: ffi_outcome_error_binary_entries(outcome),
      kind,
    })
  }
}
