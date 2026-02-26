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
test "normalize_backend_error maps invalid usage to invalid argument" {
  let backend_error : @internal.BackendError = {
    code: 3,
    message: "concurrent unary wait is not supported",
    details: Some("UnaryCall.wait called concurrently"),
    metadata_text: [],
    metadata_binary: [],
    kind: @internal.InvalidUsage,
  }

  let normalized = normalize_backend_error(backend_error)

  assert_eq(normalized.code, InvalidArgument)
  assert_eq(normalized.message, "concurrent unary wait is not supported")
  assert_eq(normalized.details, Some("UnaryCall.wait called concurrently"))
  assert_eq(normalized.metadata, Metadata::new())
  assert_eq(normalized.kind, InvalidArgument)
}

///|
test "normalize_backend_error maps unknown backend kind to internal" {
  let backend_error : @internal.BackendError = {
    code: 13,
    message: "backend returned unknown error kind",
    details: None,
    metadata_text: [],
    metadata_binary: [],
    kind: @internal.Unknown("unexpected_kind"),
  }

  let normalized = normalize_backend_error(backend_error)

  assert_eq(normalized.code, Internal)
  assert_eq(normalized.message, "backend returned unknown error kind")
  assert_eq(
    normalized.details,
    Some("backend returned unknown error kind: unexpected_kind"),
  )
  assert_eq(normalized.metadata, Metadata::new())
  assert_eq(normalized.kind, Internal)
}

///|
test "normalize_backend_error preserves existing details for unknown backend kind" {
  let backend_error : @internal.BackendError = {
    code: 13,
    message: "backend failure",
    details: Some("raw backend detail"),
    metadata_text: [],
    metadata_binary: [],
    kind: @internal.Unknown("future_kind"),
  }

  let normalized = normalize_backend_error(backend_error)

  assert_eq(normalized.code, Internal)
  assert_eq(normalized.message, "backend failure")
  assert_eq(
    normalized.details,
    Some("raw backend detail; backend returned unknown error kind: future_kind"),
  )
  assert_eq(normalized.metadata, Metadata::new())
  assert_eq(normalized.kind, Internal)
}

///|
test "normalize_backend_error normalizes channel closed status code to cancelled" {
  let backend_error : @internal.BackendError = {
    code: 13,
    message: "channel is closed",
    details: None,
    metadata_text: [],
    metadata_binary: [],
    kind: @internal.ChannelClosed,
  }

  let normalized = normalize_backend_error(backend_error)

  assert_eq(normalized.code, Cancelled)
  assert_eq(normalized.message, "channel is closed")
  assert_eq(normalized.details, None)
  assert_eq(normalized.metadata, Metadata::new())
  assert_eq(normalized.kind, ChannelClosed)
}

///|
test "normalize_backend_error reconstructs backend metadata" {
  let backend_error : @internal.BackendError = {
    code: 2,
    message: "server error",
    details: Some("debug detail"),
    metadata_text: [("x-request-id", ["req-123"]), ("server", ["grpc-test"])],
    metadata_binary: [("trace-bin", [b"\x01\x02"])],
    kind: @internal.Status,
  }
  let expected_metadata = Metadata::new()
  assert_eq(expected_metadata.add_text("x-request-id", "req-123"), Ok(()))
  assert_eq(expected_metadata.add_text("server", "grpc-test"), Ok(()))
  assert_eq(expected_metadata.add_binary("trace-bin", b"\x01\x02"), Ok(()))

  let normalized = normalize_backend_error(backend_error)

  assert_eq(normalized.code, Unknown)
  assert_eq(normalized.message, "server error")
  assert_eq(normalized.details, Some("debug detail"))
  assert_eq(normalized.metadata, expected_metadata)
  assert_eq(normalized.kind, Status)
}

///|
test "normalize_backend_error silently drops invalid backend metadata" {
  let backend_error : @internal.BackendError = {
    code: 2,
    message: "server error",
    details: None,
    metadata_text: [("x-request-id", ["req-123"]), ("x key", ["bad"])],
    metadata_binary: [("trace-bin", [b"\x01\x02"]), ("trace", [b"\x03"])],
    kind: @internal.Status,
  }
  let expected_metadata = Metadata::new()
  assert_eq(expected_metadata.add_text("x-request-id", "req-123"), Ok(()))
  assert_eq(expected_metadata.add_binary("trace-bin", b"\x01\x02"), Ok(()))

  let normalized = normalize_backend_error(backend_error)

  assert_eq(normalized.metadata, expected_metadata)
  assert_eq(normalized.metadata.get("x key"), [])
  assert_eq(normalized.metadata.get("trace"), [])
}
