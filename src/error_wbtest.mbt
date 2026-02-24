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
