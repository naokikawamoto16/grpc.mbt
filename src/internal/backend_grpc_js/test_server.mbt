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
  priv inner : JsTestServer
}

///|
pub async fn start_test_server_insecure() -> TestServer {
  let inner = @js_async.run_promise(signal => {
    ignore(signal)
    ffi_test_server_start(true, None, None)
  })
  { inner, }
}

///|
pub async fn start_test_server_tls(
  cert_chain : Bytes,
  private_key : Bytes,
) -> TestServer {
  let inner = @js_async.run_promise(signal => {
    ignore(signal)
    ffi_test_server_start(false, Some(cert_chain), Some(private_key))
  })
  { inner, }
}

///|
pub fn TestServer::port(self : TestServer) -> Int {
  ffi_test_server_port(self.inner)
}

///|
pub async fn TestServer::stop(self : TestServer) -> Unit {
  ignore(
    @js_async.run_promise(signal => {
      ignore(signal)
      ffi_test_server_stop(self.inner)
    }),
  )
}

///|
pub async fn read_text_file(path : String) -> String {
  @js_async.run_promise(signal => {
    ignore(signal)
    ffi_read_text_file(path)
  })
}

///|
pub async fn generate_test_tls_material() -> (Bytes, Bytes) {
  let generated = @js_async.run_promise(signal => {
    ignore(signal)
    ffi_generate_test_tls_material()
  })
  if generated.length() < 2 {
    panic()
  }
  (generated[0], generated[1])
}
