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
fn error_from_exception(err : Error) -> RawError {
  let text = err.to_string()
  let cancelled = @async.is_cancellation_error(err)
  raw_error(
    if cancelled {
      grpc_cancelled
    } else {
      grpc_internal
    },
    text,
    if cancelled {
      "cancelled"
    } else {
      "internal"
    },
    None,
  )
}

///|
fn codec_decode_error(err : Error) -> RawError {
  raw_error(
    grpc_internal,
    "codec decode failed",
    "codec_decode",
    Some(err.to_string()),
  )
}

///|
pub fn cancel_unary(call : UnaryCall) -> Unit {
  ffi_unary_cancel(call.inner)
}

///|
pub fn is_unary_done(call : UnaryCall) -> Bool {
  if call.cached is Some(_) {
    return true
  }
  ffi_unary_is_done(call.inner)
}

///|
async fn await_cached_result_while_in_progress(
  call : UnaryCall,
) -> RawUnaryOutcome {
  if call.cached is Some(result) {
    return result
  }
  let yielded : Result[Unit, Error] = try? @async.sleep(1)
  match yielded {
    Ok(_) => await_cached_result_while_in_progress(call)
    Err(err) => Failure(error_from_exception(err))
  }
}

///|
pub async fn await_unary(call : UnaryCall) -> RawUnaryOutcome {
  if call.cached is Some(result) {
    return result
  }
  if call.awaiting {
    return await_cached_result_while_in_progress(call)
  }

  call.awaiting = true

  let waited : Result[JsUnaryOutcome, Error] = try? @js_async.run_promise(signal => {
    ffi_unary_wait(call.inner, signal)
  })
  let normalized = match waited {
    Ok(outcome) => from_js_outcome(outcome)
    Err(err) => Failure(error_from_exception(err))
  }
  call.cached = Some(normalized)
  call.awaiting = false
  normalized
}

///|
pub async fn[Resp] await_unary_with_codec(
  call : UnaryCall,
  decode : (Bytes) -> Resp raise,
) -> Result[Resp, RawError] {
  match await_unary(call) {
    Success(payload) => {
      let decoded : Result[Resp, Error] = try? decode(payload)
      match decoded {
        Ok(response) => Ok(response)
        Err(err) => Err(codec_decode_error(err))
      }
    }
    Failure(error) => Err(error)
  }
}
