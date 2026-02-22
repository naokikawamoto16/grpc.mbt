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
extern "js" fn test_js_unary_outcome_ok(response : Bytes) -> JsUnaryOutcome =
  #| (response) => ({ ok: true, response })

///|
extern "js" fn test_js_unary_outcome_error(
  code : Int,
  message : String,
  details : String?,
  kind : String,
  metadata_text : Array[(String, Array[String])],
  metadata_binary : Array[(String, Array[Bytes])],
) -> JsUnaryOutcome =
  #| (code, message, details, kind, metadata_text, metadata_binary) => ({
  #|   ok: false,
  #|   code,
  #|   message,
  #|   details,
  #|   kind,
  #|   metadataText: metadata_text,
  #|   metadataBinary: metadata_binary,
  #| })

///|
test "from_js_outcome converts success payload" {
  let payload = b"\x01\x02grpc"
  assert_eq(
    from_js_outcome(test_js_unary_outcome_ok(payload)),
    Success(payload),
  )
}

///|
test "from_js_outcome converts error fields and normalizes generic kind" {
  let outcome = test_js_unary_outcome_error(
    grpc_deadline_exceeded,
    "deadline exceeded",
    Some("upstream timeout"),
    "transport",
    [("x-request-id", ["req-123"])],
    [("trace-bin", [b"\x01\x02\x03"])],
  )
  assert_eq(
    from_js_outcome(outcome),
    Failure({
      code: grpc_deadline_exceeded,
      message: "deadline exceeded",
      details: Some("upstream timeout"),
      metadata_text: [("x-request-id", ["req-123"])],
      metadata_binary: [("trace-bin", [b"\x01\x02\x03"])],
      kind: "timeout",
    }),
  )
}
