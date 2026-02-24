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
pub(all) enum BackendErrorKind {
  Status
  Transport
  Timeout
  Cancelled
  CodecEncode
  CodecDecode
  ChannelClosed
  InvalidUsage
  Internal
  Unknown(String)
} derive(Show, Eq, ToJson)

///|
pub(all) struct BackendError {
  code : Int
  message : String
  details : String?
  metadata_text : Array[(String, Array[String])]
  metadata_binary : Array[(String, Array[Bytes])]
  kind : BackendErrorKind
} derive(Show, Eq, ToJson)

///|
pub(all) struct BackendTlsOptions {
  root_certs : Bytes?
  private_key : Bytes?
  cert_chain : Bytes?
  server_name_override : String?
  reject_unauthorized : Bool?
} derive(Eq)

///|
pub(all) enum BackendSecurity {
  Insecure
  Tls(BackendTlsOptions)
} derive(Eq)

///|
pub(all) struct BackendChannelOptions {
  security : BackendSecurity
  max_send_message_length : Int?
  max_receive_message_length : Int?
  keepalive_time_ms : Int?
  keepalive_timeout_ms : Int?
  default_authority : String?
  user_agent : String?
} derive(Eq)

///|
pub(all) struct BackendCallOptions {
  metadata_text : Array[(String, Array[String])]
  metadata_binary : Array[(String, Array[Bytes])]
  timeout_ms : Int?
  wait_for_ready : Bool
} derive(Show, Eq, ToJson)

///|
pub(all) struct ChannelHandle {
  priv inner : @impl.Channel
}

///|
pub(all) struct UnaryHandle[Resp] {
  priv inner : @impl.UnaryCall
  priv done : FinishOnce[Result[Resp, BackendError]]
  priv mut awaiting : Bool
  priv decode : (Bytes) -> Resp raise
}
