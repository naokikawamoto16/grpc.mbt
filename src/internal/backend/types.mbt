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
pub(all) struct RawTlsOptions {
  root_certs : Bytes?
  private_key : Bytes?
  cert_chain : Bytes?
  server_name_override : String?
  reject_unauthorized : Bool?
} derive(Show, Eq, ToJson)

///|
pub(all) enum RawSecurity {
  Insecure
  Tls(RawTlsOptions)
} derive(Show, Eq, ToJson)

///|
pub(all) struct RawChannelOptions {
  security : RawSecurity
  max_send_message_length : Int?
  max_receive_message_length : Int?
  keepalive_time_ms : Int?
  keepalive_timeout_ms : Int?
  default_authority : String?
  user_agent : String?
} derive(Show, Eq, ToJson)

///|
pub(all) struct RawCallOptions {
  metadata_text : Array[(String, Array[String])]
  metadata_binary : Array[(String, Array[Bytes])]
  timeout_ms : Int?
  wait_for_ready : Bool
} derive(Show, Eq, ToJson)

///|
/// Classification of a raw backend error.
///
/// - `Status` – the server returned a non-OK gRPC status.
/// - `Transport` – a network-level error occurred.
/// - `Timeout` – the deadline was exceeded.
/// - `Cancelled` – the call was cancelled by the caller.
/// - `CodecEncode` – encoding the request message failed.
/// - `CodecDecode` – decoding the response message failed.
/// - `ChannelClosed` – the underlying channel has been shut down.
/// - `Internal` – an unexpected error inside the backend.
pub(all) enum RawErrorKind {
  Status
  Transport
  Timeout
  Cancelled
  CodecEncode
  CodecDecode
  ChannelClosed
  Internal
} derive(Show, Eq, ToJson)

///|
pub(all) struct RawError {
  code : Int
  message : String
  details : String?
  metadata_text : Array[(String, Array[String])]
  metadata_binary : Array[(String, Array[Bytes])]
  kind : RawErrorKind
} derive(Show, Eq, ToJson)

///|
pub(all) enum RawUnaryOutcome {
  Success(Bytes)
  Failure(RawError)
} derive(Show, Eq, ToJson)
