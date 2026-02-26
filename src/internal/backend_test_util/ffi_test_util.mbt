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
extern "js" fn ffi_inject_next_client_start_unary_exception(
  marker_key : String,
  marker_value : String,
) =
  #| (marker_key, marker_value) => {
  #|   const grpc = require("@grpc/grpc-js");
  #|   const proto = grpc?.Client?.prototype;
  #|   if (!proto || typeof proto.makeUnaryRequest !== "function") {
  #|     throw new Error("grpc-js Client.makeUnaryRequest is not available");
  #|   }
  #|   const armedKey = "__grpcTestNextUnaryStartExceptionArmed";
  #|   const originalKey = "__grpcTestOriginalMakeUnaryRequest";
  #|   const markerKeyKey = "__grpcTestNextUnaryStartExceptionMarkerKey";
  #|   const markerValueKey = "__grpcTestNextUnaryStartExceptionMarkerValue";
  #|   const restore = () => {
  #|     const original = proto[originalKey];
  #|     if (typeof original === "function") {
  #|       proto.makeUnaryRequest = original;
  #|       delete proto[originalKey];
  #|     }
  #|     proto[armedKey] = false;
  #|     delete proto[markerKeyKey];
  #|     delete proto[markerValueKey];
  #|   };
  #|   if (proto[armedKey]) {
  #|     throw new Error("grpc-js Client.makeUnaryRequest exception injection is already armed");
  #|   }
  #|   if (typeof proto[originalKey] !== "function") {
  #|     proto[originalKey] = proto.makeUnaryRequest;
  #|   }
  #|   proto[armedKey] = true;
  #|   proto[markerKeyKey] = String(marker_key);
  #|   proto[markerValueKey] = String(marker_value);
  #|   proto.makeUnaryRequest = function (..._args) {
  #|     const original = proto[originalKey];
  #|     if (typeof original !== "function") {
  #|       restore();
  #|       throw new Error("grpc-js original makeUnaryRequest is not available");
  #|     }
  #|     const metadata = _args[4];
  #|     const scopedMarkerKey = proto[markerKeyKey];
  #|     const scopedMarkerValue = proto[markerValueKey];
  #|     let shouldThrow = false;
  #|     if (
  #|       metadata &&
  #|       typeof metadata.get === "function" &&
  #|       typeof scopedMarkerKey === "string" &&
  #|       typeof scopedMarkerValue === "string"
  #|     ) {
  #|       const values = metadata.get(scopedMarkerKey) || [];
  #|       shouldThrow = values.some((value) => String(value) === scopedMarkerValue);
  #|     }
  #|     if (!shouldThrow) {
  #|       return original.apply(this, _args);
  #|     }
  #|     restore();
  #|     throw new Error("forced js exception");
  #|   };
  #| }

///|
extern "js" fn ffi_restore_client_start_unary_exception_injection() =
  #| () => {
  #|   const grpc = require("@grpc/grpc-js");
  #|   const proto = grpc?.Client?.prototype;
  #|   if (!proto) {
  #|     return;
  #|   }
  #|   const armedKey = "__grpcTestNextUnaryStartExceptionArmed";
  #|   const originalKey = "__grpcTestOriginalMakeUnaryRequest";
  #|   const markerKeyKey = "__grpcTestNextUnaryStartExceptionMarkerKey";
  #|   const markerValueKey = "__grpcTestNextUnaryStartExceptionMarkerValue";
  #|   const original = proto[originalKey];
  #|   if (typeof original === "function") {
  #|     proto.makeUnaryRequest = original;
  #|     delete proto[originalKey];
  #|   }
  #|   proto[armedKey] = false;
  #|   delete proto[markerKeyKey];
  #|   delete proto[markerValueKey];
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
  #|       if (text === "metadata:echo") {
  #|         try {
  #|           const getText = (key) => (call.metadata.get(key) || []).map((v) => String(v));
  #|           const getBinary = (key) =>
  #|             (call.metadata.get(key) || []).map((v) => Buffer.from(v).toString("hex"));
  #|           const reflected = [
  #|             `x-request-id=${getText("x-request-id").join(",")}`,
  #|             `x-tag=${getText("x-tag").join(",")}`,
  #|             `x-empty=${getText("x-empty").join(",")}`,
  #|             `trace-bin=${getBinary("trace-bin").join(",")}`,
  #|             `empty-bin=${getBinary("empty-bin").join(",")}`,
  #|           ].join(";");
  #|           callback(null, Buffer.from(reflected, "utf8"));
  #|         } catch (err) {
  #|           callback(err);
  #|         }
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
  #|   new Promise((resolve, reject) => {
  #|     const rawServer = server?.server;
  #|     if (!rawServer) {
  #|       reject(new Error("grpc-js test server wrapper is invalid"));
  #|       return;
  #|     }
  #|     if (typeof rawServer.tryShutdown !== "function") {
  #|       reject(new Error("grpc-js Server.tryShutdown is not available"));
  #|       return;
  #|     }
  #|     try {
  #|       rawServer.tryShutdown((error) => {
  #|         if (error) {
  #|           reject(error instanceof Error ? error : new Error(String(error)));
  #|           return;
  #|         }
  #|         resolve();
  #|       });
  #|     } catch (error) {
  #|       reject(error instanceof Error ? error : new Error(String(error)));
  #|     }
  #|   })
