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
pub type JsChannel

///|
#external
pub type JsUnaryCall

///|
#external
pub type JsUnaryOutcome

///|
extern "js" fn ffi_require_grpc_js() -> Bool =
  #| () => {
  #|   try {
  #|     require("@grpc/grpc-js");
  #|     return true;
  #|   } catch (_) {
  #|     return false;
  #|   }
  #| }

///|
extern "js" fn ffi_new_channel(
  target : String,
  insecure : Bool,
  root_certs : Bytes?,
  private_key : Bytes?,
  cert_chain : Bytes?,
  server_name_override : String?,
  reject_unauthorized : Bool?,
  max_send_message_length : Int?,
  max_receive_message_length : Int?,
  keepalive_time_ms : Int?,
  keepalive_timeout_ms : Int?,
  default_authority : String?,
  user_agent : String?,
) -> JsChannel =
  #| (
  #|   target,
  #|   insecure,
  #|   root_certs,
  #|   private_key,
  #|   cert_chain,
  #|   server_name_override,
  #|   reject_unauthorized,
  #|   max_send_message_length,
  #|   max_receive_message_length,
  #|   keepalive_time_ms,
  #|   keepalive_timeout_ms,
  #|   default_authority,
  #|   user_agent,
  #| ) => {
  #|   const grpc = require("@grpc/grpc-js");
  #|   const options = {};
  #|   if (max_send_message_length !== undefined && max_send_message_length !== null) {
  #|     options["grpc.max_send_message_length"] = max_send_message_length;
  #|   }
  #|   if (max_receive_message_length !== undefined && max_receive_message_length !== null) {
  #|     options["grpc.max_receive_message_length"] = max_receive_message_length;
  #|   }
  #|   if (keepalive_time_ms !== undefined && keepalive_time_ms !== null) {
  #|     options["grpc.keepalive_time_ms"] = keepalive_time_ms;
  #|   }
  #|   if (keepalive_timeout_ms !== undefined && keepalive_timeout_ms !== null) {
  #|     options["grpc.keepalive_timeout_ms"] = keepalive_timeout_ms;
  #|   }
  #|   if (default_authority !== undefined && default_authority !== null) {
  #|     options["grpc.default_authority"] = default_authority;
  #|   }
  #|   if (user_agent !== undefined && user_agent !== null) {
  #|     options["grpc.primary_user_agent"] = user_agent;
  #|   }
  #|   if (server_name_override !== undefined && server_name_override !== null) {
  #|     options["grpc.ssl_target_name_override"] = server_name_override;
  #|   }
  #|   const counters = globalThis.__grpcConversionCounters || (globalThis.__grpcConversionCounters = {
  #|     bytesToBuffer: 0,
  #|     bufferToBytes: 0,
  #|   });
  #|   const fromBytes = (bytes) => {
  #|     if (bytes == null) {
  #|       return null;
  #|     }
  #|     counters.bytesToBuffer += 1;
  #|     return Buffer.from(bytes);
  #|   };
  #|   const verifyOptions =
  #|     reject_unauthorized !== undefined && reject_unauthorized !== null
  #|       ? { rejectUnauthorized: Boolean(reject_unauthorized) }
  #|       : undefined;
  #|   const credentials = insecure
  #|     ? grpc.credentials.createInsecure()
  #|     : grpc.credentials.createSsl(
  #|         fromBytes(root_certs),
  #|         fromBytes(private_key),
  #|         fromBytes(cert_chain),
  #|         verifyOptions,
  #|       );
  #|   const client = new grpc.Client(target, credentials, options);
  #|   return {
  #|     grpc,
  #|     client,
  #|     closed: false,
  #|     active: new Set(),
  #|   };
  #| }

///|
extern "js" fn ffi_channel_close(channel : JsChannel) =
  #| (channel) => {
  #|   if (channel.closed) {
  #|     return;
  #|   }
  #|   channel.closed = true;
  #|   for (const call of Array.from(channel.active)) {
  #|     try {
  #|       call.cancel();
  #|     } catch (_) {
  #|       // no-op
  #|     }
  #|   }
  #|   channel.active.clear();
  #|   channel.client.close();
  #| }

///|
extern "js" fn ffi_channel_is_closed(channel : JsChannel) -> Bool =
  #| (channel) => Boolean(channel.closed)

///|
extern "js" fn ffi_start_unary(
  channel : JsChannel,
  path : String,
  request : Bytes,
  text_keys : Array[String],
  text_values : Array[String],
  binary_keys : Array[String],
  binary_values : Array[Bytes],
  timeout_ms : Int?,
  wait_for_ready : Bool,
) -> JsUnaryCall =
  #| (
  #|   channel,
  #|   path,
  #|   request,
  #|   text_keys,
  #|   text_values,
  #|   binary_keys,
  #|   binary_values,
  #|   timeout_ms,
  #|   wait_for_ready,
  #| ) => {
  #|   const grpc = channel.grpc || require("@grpc/grpc-js");
  #|   const counters = globalThis.__grpcConversionCounters || (globalThis.__grpcConversionCounters = {
  #|     bytesToBuffer: 0,
  #|     bufferToBytes: 0,
  #|   });
  #|   const fromBytes = (bytes) => {
  #|     counters.bytesToBuffer += 1;
  #|     return Buffer.from(bytes);
  #|   };
  #|   const fromBuffer = (buffer) => {
  #|     counters.bufferToBytes += 1;
  #|     return Buffer.from(buffer);
  #|   };
  #|   const toMetadataArrays = (md) => {
  #|     const textEntries = [];
  #|     const binaryEntries = [];
  #|     if (!md || typeof md.getMap !== "function") {
  #|       return { textEntries, binaryEntries };
  #|     }
  #|     const map = md.getMap();
  #|     for (const key of Object.keys(map)) {
  #|       const values = md.get(key) || [];
  #|       const textValues = [];
  #|       const binaryValues = [];
  #|       for (const value of values) {
  #|         if (Buffer.isBuffer(value)) {
  #|           binaryValues.push(value);
  #|         } else if (value instanceof Uint8Array) {
  #|           counters.bytesToBuffer += 1;
  #|           binaryValues.push(Buffer.from(value));
  #|         } else {
  #|           textValues.push(String(value));
  #|         }
  #|       }
  #|       if (textValues.length > 0) {
  #|         textEntries.push({ _0: key, _1: textValues });
  #|       }
  #|       if (binaryValues.length > 0) {
  #|         binaryEntries.push({ _0: key, _1: binaryValues });
  #|       }
  #|     }
  #|     return { textEntries, binaryEntries };
  #|   };
  #|   const normalizeError = (status, kindHint) => {
  #|     const code = Number.isInteger(status?.code) ? status.code : grpc.status.UNKNOWN;
  #|     const message = status?.details || status?.message || String(status);
  #|     const details = status?.details == null ? null : String(status.details);
  #|     const metadata = toMetadataArrays(status?.metadata);
  #|     let kind = kindHint || "status";
  #|     if (code === grpc.status.CANCELLED) {
  #|       kind = "cancelled";
  #|     }
  #|     if (code === grpc.status.DEADLINE_EXCEEDED) {
  #|       kind = "timeout";
  #|     }
  #|     return {
  #|       ok: false,
  #|       code,
  #|       message,
  #|       details,
  #|       kind,
  #|       metadataText: metadata.textEntries,
  #|       metadataBinary: metadata.binaryEntries,
  #|     };
  #|   };
  #|
  #|   let resolvePromise;
  #|   const handle = {
  #|     call: null,
  #|     done: false,
  #|     outcome: null,
  #|     promise: null,
  #|     cancel: () => {
  #|       if (handle.done) {
  #|         return;
  #|       }
  #|       if (handle.call) {
  #|         try {
  #|           handle.call.cancel();
  #|         } catch (_) {
  #|           // no-op
  #|         }
  #|       }
  #|     },
  #|     waitWithSignal: (signal) =>
  #|       new Promise((resolve) => {
  #|         if (signal && typeof signal.addEventListener === "function") {
  #|           signal.addEventListener(
  #|             "abort",
  #|             () => {
  #|               handle.cancel();
  #|             },
  #|             { once: true },
  #|           );
  #|         }
  #|         handle.promise.then((outcome) => resolve(outcome));
  #|       }),
  #|   };
  #|   const settle = (outcome) => {
  #|     if (handle.done) {
  #|       return;
  #|     }
  #|     handle.done = true;
  #|     handle.outcome = outcome;
  #|     resolvePromise(outcome);
  #|   };
  #|   handle.promise = new Promise((resolve) => {
  #|     resolvePromise = resolve;
  #|   });
  #|
  #|   if (channel.closed) {
  #|     settle({
  #|       ok: false,
  #|       code: grpc.status.CANCELLED,
  #|       message: "channel is closed",
  #|       details: null,
  #|       kind: "channel_closed",
  #|       metadataText: [],
  #|       metadataBinary: [],
  #|     });
  #|     return handle;
  #|   }
  #|
  #|   try {
  #|     if (path === "/__internal__/throw_js_exception") {
  #|       throw new Error("forced js exception");
  #|     }
  #|     const metadata = new grpc.Metadata();
  #|     for (let i = 0; i < text_keys.length; i += 1) {
  #|       metadata.add(text_keys[i], text_values[i]);
  #|     }
  #|     for (let i = 0; i < binary_keys.length; i += 1) {
  #|       metadata.add(binary_keys[i], fromBytes(binary_values[i]));
  #|     }
  #|     const callOptions = {};
  #|     if (timeout_ms !== undefined && timeout_ms !== null) {
  #|       callOptions.deadline = new Date(Date.now() + timeout_ms);
  #|     }
  #|     if (wait_for_ready) {
  #|       metadata.setOptions({ waitForReady: true });
  #|     }
  #|     const serialize = (bytes) => fromBytes(bytes);
  #|     const deserialize = (buffer) => fromBuffer(buffer);
  #|     const call = channel.client.makeUnaryRequest(
  #|       path,
  #|       serialize,
  #|       deserialize,
  #|       request,
  #|       metadata,
  #|       callOptions,
  #|       (error, response) => {
  #|         if (error) {
  #|           settle(normalizeError(error, "status"));
  #|           return;
  #|         }
  #|         settle({
  #|           ok: true,
  #|           response,
  #|         });
  #|       },
  #|     );
  #|     handle.call = call;
  #|     channel.active.add(handle);
  #|     handle.promise.finally(() => {
  #|       channel.active.delete(handle);
  #|     });
  #|     call.on("status", (status) => {
  #|       if (status && status.code !== grpc.status.OK) {
  #|         settle(normalizeError(status, "status"));
  #|       }
  #|     });
  #|     call.on("error", (error) => {
  #|       settle(normalizeError(error, "transport"));
  #|     });
  #|   } catch (error) {
  #|     settle({
  #|       ok: false,
  #|       code: grpc.status.INTERNAL,
  #|       message: String(error),
  #|       details: null,
  #|       kind: "internal",
  #|       metadataText: [],
  #|       metadataBinary: [],
  #|     });
  #|   }
  #|   return handle;
  #| }

///|
extern "js" fn ffi_unary_cancel(call : JsUnaryCall) =
  #| (call) => {
  #|   call.cancel();
  #| }

///|
extern "js" fn ffi_unary_is_done(call : JsUnaryCall) -> Bool =
  #| (call) => Boolean(call.done)

///|
extern "js" fn ffi_unary_wait(
  call : JsUnaryCall,
  signal : @js_async.AbortSignal,
) -> @js_async.Promise[JsUnaryOutcome] =
  #| (call, signal) => call.waitWithSignal(signal)

///|
extern "js" fn ffi_outcome_is_ok(outcome : JsUnaryOutcome) -> Bool =
  #| (outcome) => Boolean(outcome.ok)

///|
extern "js" fn ffi_outcome_response(outcome : JsUnaryOutcome) -> Bytes =
  #| (outcome) => {
  #|   const counters = globalThis.__grpcConversionCounters || (globalThis.__grpcConversionCounters = {
  #|     bytesToBuffer: 0,
  #|     bufferToBytes: 0,
  #|   });
  #|   counters.bufferToBytes += 1;
  #|   return Buffer.from(outcome.response);
  #| }

///|
extern "js" fn ffi_outcome_error_code(outcome : JsUnaryOutcome) -> Int =
  #| (outcome) => outcome.code | 0

///|
extern "js" fn ffi_outcome_error_message(outcome : JsUnaryOutcome) -> String =
  #| (outcome) => String(outcome.message)

///|
extern "js" fn ffi_outcome_error_details(outcome : JsUnaryOutcome) -> String? =
  #| (outcome) => outcome.details == null ? null : String(outcome.details)

///|
extern "js" fn ffi_outcome_error_kind(outcome : JsUnaryOutcome) -> String =
  #| (outcome) => String(outcome.kind || "")

///|
extern "js" fn ffi_outcome_error_text_entries(
  outcome : JsUnaryOutcome,
) -> Array[(String, Array[String])] =
  #| (outcome) => outcome.metadataText || []

///|
extern "js" fn ffi_outcome_error_binary_entries(
  outcome : JsUnaryOutcome,
) -> Array[(String, Array[Bytes])] =
  #| (outcome) => outcome.metadataBinary || []
