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
pub struct TestServer {
  priv inner : @impl.TestServer
}

///|
pub async fn start_test_server_insecure() -> TestServer {
  { inner: @impl.start_test_server_insecure() }
}

///|
pub async fn start_test_server_tls(
  cert_chain : Bytes,
  private_key : Bytes,
) -> TestServer {
  { inner: @impl.start_test_server_tls(cert_chain, private_key) }
}

///|
pub fn TestServer::port(self : TestServer) -> Int {
  self.inner.port()
}

///|
pub async fn TestServer::stop(self : TestServer) -> Unit {
  self.inner.stop()
}

///|
pub async fn read_text_file(path : String) -> String {
  @impl.read_text_file(path)
}

///|
pub async fn generate_test_tls_material() -> (Bytes, Bytes) {
  @impl.generate_test_tls_material()
}
