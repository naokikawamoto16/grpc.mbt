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
/// gRPC CANCELLED status code (1).
let grpc_cancelled : Int = 1

///|
/// gRPC DEADLINE_EXCEEDED status code (4).
let grpc_deadline_exceeded : Int = 4

///|
/// gRPC INTERNAL status code (13).
let grpc_internal : Int = 13

///|
fn normalize_raw_kind(kind : String, code : Int) -> String {
  if kind.length() > 0 {
    return kind
  }
  if code == grpc_cancelled {
    "cancelled"
  } else if code == grpc_deadline_exceeded {
    "timeout"
  } else {
    "status"
  }
}
