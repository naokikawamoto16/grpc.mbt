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
test "status_code_from_int maps gRPC canonical status codes" {
  let cases = [
    (0, Ok),
    (1, Cancelled),
    (2, Unknown),
    (3, InvalidArgument),
    (4, DeadlineExceeded),
    (5, NotFound),
    (6, AlreadyExists),
    (7, PermissionDenied),
    (8, ResourceExhausted),
    (9, FailedPrecondition),
    (10, Aborted),
    (11, OutOfRange),
    (12, Unimplemented),
    (13, Internal),
    (14, Unavailable),
    (15, DataLoss),
    (16, Unauthenticated),
  ]

  for case_item in cases {
    let code = case_item.0
    let expected = case_item.1

    let actual = status_code_from_int(code)

    assert_eq(actual, expected)
  }
}

///|
test "status_code_from_int maps out-of-range codes to unknown" {
  let cases = [-1, 17, 999]

  for code in cases {
    let actual = status_code_from_int(code)

    assert_eq(actual, Unknown)
  }
}
