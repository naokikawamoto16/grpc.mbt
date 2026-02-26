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
test "normalize_raw_kind canonicalizes generic cancelled/timeout kinds" {
  assert_eq(normalize_raw_kind("", grpc_cancelled), "cancelled")
  assert_eq(normalize_raw_kind("", grpc_deadline_exceeded), "timeout")
  assert_eq(normalize_raw_kind("status", grpc_cancelled), "cancelled")
  assert_eq(normalize_raw_kind("transport", grpc_deadline_exceeded), "timeout")
}

///|
test "normalize_raw_kind preserves explicit kinds and defaults empty unknown to status" {
  assert_eq(normalize_raw_kind("", grpc_internal), "status")
  assert_eq(
    normalize_raw_kind("channel_closed", grpc_cancelled),
    "channel_closed",
  )
  assert_eq(normalize_raw_kind("internal", grpc_internal), "internal")
  assert_eq(normalize_raw_kind("codec_decode", grpc_internal), "codec_decode")
}
