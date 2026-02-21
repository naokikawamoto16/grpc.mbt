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
#external
priv type JsTestServer

///|
extern "js" fn ffi_reset_conversion_counters() =
  #| () => {
  #|   globalThis.__grpcConversionCounters = {
  #|     bytesToBuffer: 0,
  #|     bufferToBytes: 0,
  #|   };
  #| }

///|
extern "js" fn ffi_get_conversion_counters() -> Array[Int] =
  #| () => {
  #|   const counters = globalThis.__grpcConversionCounters || {
  #|     bytesToBuffer: 0,
  #|     bufferToBytes: 0,
  #|   };
  #|   return [counters.bytesToBuffer | 0, counters.bufferToBytes | 0];
  #| }

///|
extern "js" fn ffi_read_text_file(path : String) -> @js_async.Promise[String] =
  #| async (path) => {
  #|   const content = await require("node:fs/promises").readFile(path, "utf8");
  #|   return String(content);
  #| }

///|
extern "js" fn ffi_generate_test_tls_material() -> @js_async.Promise[
  Array[Bytes],
] =
  #| async () => {
  #|   const fs = require("node:fs/promises");
  #|   const os = require("node:os");
  #|   const path = require("node:path");
  #|   const childProcess = require("node:child_process");
  #|   const util = require("node:util");
  #|   const execFile = util.promisify(childProcess.execFile);
  #|   const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "grpc-tls-"));
  #|   const certPath = path.join(tempDir, "server.crt");
  #|   const keyPath = path.join(tempDir, "server.key");
  #|   try {
  #|     await execFile("openssl", [
  #|       "req",
  #|       "-x509",
  #|       "-newkey",
  #|       "rsa:2048",
  #|       "-keyout",
  #|       keyPath,
  #|       "-out",
  #|       certPath,
  #|       "-sha256",
  #|       "-days",
  #|       "1",
  #|       "-nodes",
  #|       "-subj",
  #|       "/CN=localhost",
  #|     ]);
  #|     const cert = await fs.readFile(certPath);
  #|     const key = await fs.readFile(keyPath);
  #|     return [cert, key];
  #|   } finally {
  #|     await fs.rm(tempDir, { recursive: true, force: true });
  #|   }
  #| }

///|
extern "js" fn ffi_test_server_start(
  insecure : Bool,
  cert_chain : Bytes?,
  private_key : Bytes?,
) -> @js_async.Promise[JsTestServer] =
  #| (insecure, cert_chain, private_key) => {
  #|   const grpc = require("@grpc/grpc-js");
  #|   const service = {
  #|     Echo: {
  #|       path: "/test.EchoService/Echo",
  #|       requestStream: false,
  #|       responseStream: false,
  #|       requestSerialize: (value) => Buffer.from(value),
  #|       requestDeserialize: (value) => Buffer.from(value),
  #|       responseSerialize: (value) => Buffer.from(value),
  #|       responseDeserialize: (value) => Buffer.from(value),
  #|     },
  #|   };
  #|   const implementation = {
  #|     Echo(call, callback) {
  #|       const request = Buffer.from(call.request);
  #|       const text = request.toString("utf8");
  #|       if (text.startsWith("error:")) {
  #|         const first = text.indexOf(":");
  #|         const second = text.indexOf(":", first + 1);
  #|         const codeText = second < 0 ? text.slice(first + 1) : text.slice(first + 1, second);
  #|         const message = second < 0 ? "forced error" : text.slice(second + 1);
  #|         const code = Number.parseInt(codeText, 10);
  #|         const metadata = new grpc.Metadata();
  #|         metadata.add("x-error-source", "test-server");
  #|         metadata.add("trace-bin", Buffer.from([1, 2, 3, 4]));
  #|         callback({
  #|           code: Number.isInteger(code) ? code : grpc.status.UNKNOWN,
  #|           message,
  #|           details: message,
  #|           metadata,
  #|         });
  #|         return;
  #|       }
  #|       if (text.startsWith("sleep:")) {
  #|         const first = text.indexOf(":");
  #|         const second = text.indexOf(":", first + 1);
  #|         const sleepMs = Number.parseInt(text.slice(first + 1, second), 10);
  #|         const payload = text.slice(second + 1);
  #|         setTimeout(() => callback(null, Buffer.from(payload, "utf8")), Number.isInteger(sleepMs) ? sleepMs : 0);
  #|         return;
  #|       }
  #|       callback(null, request);
  #|     },
  #|   };
  #|   const server = new grpc.Server();
  #|   server.addService(service, implementation);
  #|   const credentials = insecure
  #|     ? grpc.ServerCredentials.createInsecure()
  #|     : (() => {
  #|         const counters = globalThis.__grpcConversionCounters || (globalThis.__grpcConversionCounters = {
  #|           bytesToBuffer: 0,
  #|           bufferToBytes: 0,
  #|         });
  #|         counters.bytesToBuffer += 2;
  #|         return grpc.ServerCredentials.createSsl(
  #|           null,
  #|           [{
  #|             cert_chain: Buffer.from(cert_chain),
  #|             private_key: Buffer.from(private_key),
  #|           }],
  #|           false,
  #|         );
  #|       })();
  #|   return new Promise((resolve, reject) => {
  #|     server.bindAsync("127.0.0.1:0", credentials, (error, port) => {
  #|       if (error) {
  #|         reject(error);
  #|         return;
  #|       }
  #|       resolve({ server, port });
  #|     });
  #|   });
  #| }

///|
extern "js" fn ffi_test_server_port(server : JsTestServer) -> Int =
  #| (server) => server.port | 0

///|
extern "js" fn ffi_test_server_stop(
  server : JsTestServer,
) -> @js_async.Promise[Unit] =
  #| (server) =>
  #|   new Promise((resolve) => {
  #|     server.server.tryShutdown(() => {
  #|       resolve();
  #|     });
  #|   })
