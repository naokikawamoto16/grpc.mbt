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
/// gRPC status code set.
pub(all) enum StatusCode {
  Ok
  Cancelled
  Unknown
  InvalidArgument
  DeadlineExceeded
  NotFound
  AlreadyExists
  PermissionDenied
  ResourceExhausted
  FailedPrecondition
  Aborted
  OutOfRange
  Unimplemented
  Internal
  Unavailable
  DataLoss
  Unauthenticated
} derive(Show, Eq, Compare, Hash, ToJson)

///|
/// Convert an integer to the corresponding `StatusCode`.
///
/// The mapping follows the gRPC specification (0 = Ok, 1 = Cancelled, ..., 16 = Unauthenticated).
/// Any integer outside the range 0..16 is mapped to `Unknown`.
fn status_code_from_int(code : Int) -> StatusCode {
  match code {
    0 => Ok
    1 => Cancelled
    2 => Unknown
    3 => InvalidArgument
    4 => DeadlineExceeded
    5 => NotFound
    6 => AlreadyExists
    7 => PermissionDenied
    8 => ResourceExhausted
    9 => FailedPrecondition
    10 => Aborted
    11 => OutOfRange
    12 => Unimplemented
    13 => Internal
    14 => Unavailable
    15 => DataLoss
    16 => Unauthenticated
    _ => Unknown
  }
}
