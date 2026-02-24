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
test "backend_error_kind_from_string maps known and unknown kinds" {
  assert_eq(backend_error_kind_from_string("status"), Status)
  assert_eq(backend_error_kind_from_string("transport"), Transport)
  assert_eq(backend_error_kind_from_string("timeout"), Timeout)
  assert_eq(backend_error_kind_from_string("cancelled"), Cancelled)
  assert_eq(backend_error_kind_from_string("codec_encode"), CodecEncode)
  assert_eq(backend_error_kind_from_string("codec_decode"), CodecDecode)
  assert_eq(backend_error_kind_from_string("channel_closed"), ChannelClosed)
  assert_eq(backend_error_kind_from_string("invalid_usage"), InvalidUsage)
  assert_eq(backend_error_kind_from_string("internal"), Internal)
  assert_eq(
    backend_error_kind_from_string("unexpected_kind"),
    Unknown("unexpected_kind"),
  )
}

///|
test "from_raw_error normalizes kind and preserves raw fields" {
  let raw : @impl.RawError = {
    code: 4,
    message: "deadline exceeded",
    details: Some("request timed out"),
    metadata_text: [("x-request-id", ["req-123"]), ("server", ["test"])],
    metadata_binary: [("trace-bin", [b"\x01\x02\x03"])],
    kind: "timeout",
  }

  let normalized = from_raw_error(raw)

  assert_eq(normalized.code, 4)
  assert_eq(normalized.message, "deadline exceeded")
  assert_eq(normalized.details, Some("request timed out"))
  assert_eq(normalized.metadata_text, [
    ("x-request-id", ["req-123"]),
    ("server", ["test"]),
  ])
  assert_eq(normalized.metadata_binary, [("trace-bin", [b"\x01\x02\x03"])])
  assert_eq(normalized.kind, Timeout)
}

///|
test "message_error keeps kind and code consistent for local errors" {
  let internal_error = message_error("internal failure")
  let cancelled_error = message_error("cancelled", kind=Cancelled)
  let timeout_error = message_error("timeout", kind=Timeout)
  let invalid_usage_error = message_error("invalid usage", kind=InvalidUsage)

  assert_eq(internal_error.code, 13)
  assert_eq(internal_error.message, "internal failure")
  assert_eq(internal_error.details, None)
  assert_eq(internal_error.metadata_text, [])
  assert_eq(internal_error.metadata_binary, [])
  assert_eq(internal_error.kind, Internal)

  assert_eq(cancelled_error.code, 1)
  assert_eq(cancelled_error.message, "cancelled")
  assert_eq(cancelled_error.kind, Cancelled)

  assert_eq(timeout_error.code, 4)
  assert_eq(timeout_error.kind, Timeout)

  assert_eq(invalid_usage_error.code, 3)
  assert_eq(invalid_usage_error.kind, InvalidUsage)
}
