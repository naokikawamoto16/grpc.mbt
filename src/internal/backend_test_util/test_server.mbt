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
pub(all) struct BackendTest {}

///|
pub(all) struct TestServer {
  priv inner : JsTestServer
}

///|
let client_start_unary_exception_marker_key : String = "x-grpc-test-js-exception-marker"

///|
/// Start a test-only grpc-js server with insecure credentials.
/// The server binds to `127.0.0.1` on an OS-assigned port.
pub async fn BackendTest::start_test_server_insecure() -> TestServer {
  let inner = @js_async.run_promise(signal => {
    ignore(signal)
    ffi_test_server_start(true, None, None)
  })
  { inner, }
}

///|
/// Start a test-only grpc-js server with TLS credentials.
/// The server binds to `127.0.0.1` on an OS-assigned port.
pub async fn BackendTest::start_test_server_tls(
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
/// Return the bound port of this test server.
pub fn TestServer::port(self : TestServer) -> Int {
  ffi_test_server_port(self.inner)
}

///|
/// Stop this test server asynchronously.
/// Shutdown errors from the FFI layer are propagated.
pub async fn TestServer::stop(self : TestServer) -> Unit {
  ignore(
    @js_async.run_promise(signal => {
      ignore(signal)
      ffi_test_server_stop(self.inner)
    }),
  )
}

///|
/// Read a UTF-8 text file for tests.
pub async fn BackendTest::read_text_file(path : String) -> String {
  @js_async.run_promise(signal => {
    ignore(signal)
    ffi_read_text_file(path)
  })
}

///|
/// Generate temporary TLS material for tests.
/// Returns `(cert_chain, private_key)` and aborts on an invalid FFI result shape.
pub async fn BackendTest::generate_test_tls_material() -> (Bytes, Bytes) {
  let materials = @js_async.run_promise(signal => {
    ignore(signal)
    ffi_generate_test_tls_material()
  })
  if materials.length() != 2 {
    abort("ffi_generate_test_tls_material must return exactly 2 items")
  }
  (materials[0], materials[1])
}

///|
/// Return the metadata key used to scope client unary-start exception injection.
pub fn BackendTest::client_start_unary_exception_marker_key() -> String {
  client_start_unary_exception_marker_key
}

///|
/// Test-only hook to force a marked grpc-js unary start to throw on the client side.
pub fn BackendTest::inject_next_client_start_unary_exception(
  marker_value : String,
) -> Unit {
  ffi_inject_next_client_start_unary_exception(
    client_start_unary_exception_marker_key, marker_value,
  )
}

///|
/// Restore grpc-js client unary-start exception injection if it is still armed.
pub fn BackendTest::restore_client_start_unary_exception_injection() -> Unit {
  ffi_restore_client_start_unary_exception_injection()
}
