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
suberror TestWriteFail

///|
suberror TestReadFail

///|
struct EchoProtoMessage {
  text : String
} derive(Eq, Show)

///|
pub impl @protobuf.Write for EchoProtoMessage with write(
  self : EchoProtoMessage,
  writer : &@protobuf.Writer,
) -> Unit raise {
  writer |> @protobuf.write_string(self.text)
}

///|
pub impl @protobuf.Read for EchoProtoMessage with read_with_limit(
  reader : @protobuf.LimitedReader[&@protobuf.Reader],
) -> EchoProtoMessage raise {
  { text: reader |> @protobuf.read_string() }
}

///|
struct EncodeFailMessage {}

///|
pub impl @protobuf.Write for EncodeFailMessage with write(
  _self : EncodeFailMessage,
  _writer : &@protobuf.Writer,
) -> Unit raise {
  raise TestWriteFail
}

///|
struct DecodeFailMessage {}

///|
pub impl @protobuf.Read for DecodeFailMessage with read_with_limit(
  _reader : @protobuf.LimitedReader[&@protobuf.Reader],
) -> DecodeFailMessage raise {
  raise TestReadFail
}

///|
async fn new_insecure_client_for_protobuf_codec_test() -> (
  Client,
  Channel,
  @backend_test_util.TestServer,
) {
  let server = @backend_test_util.BackendTest::start_test_server_insecure()
  let target = "127.0.0.1:\{server.port()}"
  let channel = Channel::new(target).unwrap()
  (Client::new(channel), channel, server)
}

///|
async fn with_protobuf_codec_test_client(f : async (Client) -> Unit) -> Unit {
  @async.with_task_group(root => {
    let setup = new_insecure_client_for_protobuf_codec_test()
    let client = setup.0
    let channel = setup.1
    let server = setup.2
    defer root.spawn_bg(allow_failure=true, () => server.stop())
    defer channel.close()
    f(client)
  })
}

///|
test "encode_protobuf/decode_protobuf round trip" {
  let message = { text: "hello protobuf" }
  let encoded = encode_protobuf(message)
  let decoded : EchoProtoMessage = decode_protobuf(encoded)
  assert_eq(decoded, message)
}

///|
test "protobuf_codec round trip" {
  let codec : Codec[EchoProtoMessage, EchoProtoMessage] = protobuf_codec()
  let message = { text: "hello codec" }
  let encoded = (codec.encode)(message)
  let decoded = (codec.decode)(encoded)
  assert_eq(decoded, message)
}

///|
async test "protobuf_codec unary success round trip over echo backend" {
  with_protobuf_codec_test_client(client => {
    let codec : Codec[EchoProtoMessage, EchoProtoMessage] = protobuf_codec()
    let descriptor = MethodDescriptor::new("test.EchoService", "Echo", codec).unwrap()

    let request = { text: "hello grpc" }
    let response = client.unary(descriptor, request)
    assert_eq(response, Ok(request))
  })
}

///|
async test "protobuf_codec encode failure is normalized to CodecEncode" {
  with_protobuf_codec_test_client(client => {
    let codec : Codec[EncodeFailMessage, EchoProtoMessage] = protobuf_codec()
    let descriptor = MethodDescriptor::new("test.EchoService", "Echo", codec).unwrap()

    let request = EncodeFailMessage::{  }
    let result = client.unary(descriptor, request)
    match result {
      Ok(_) => panic()
      Err(err) => assert_eq(err.kind, CodecEncode)
    }
  })
}

///|
async test "protobuf_codec decode failure is normalized to CodecDecode" {
  with_protobuf_codec_test_client(client => {
    let _ = DecodeFailMessage::{  }
    let codec : Codec[EchoProtoMessage, DecodeFailMessage] = protobuf_codec()
    let descriptor = MethodDescriptor::new("test.EchoService", "Echo", codec).unwrap()

    let result = client.unary(descriptor, { text: "decode-fail" })
    match result {
      Ok(_) => panic()
      Err(err) => assert_eq(err.kind, CodecDecode)
    }
  })
}
