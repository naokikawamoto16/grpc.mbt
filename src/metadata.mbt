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
/// Value type for metadata entries.
pub(all) enum MetadataValue {
  Text(String)
  Binary(Bytes)
} derive(Show, Eq, ToJson)

///|
/// Case-insensitive multi-value metadata map.
pub(all) struct Metadata {
  priv entries_map : Map[String, Array[MetadataValue]]
} derive(Show, Eq, ToJson)

///|
/// Create an empty metadata map.
pub fn Metadata::new() -> Metadata {
  { entries_map: {} }
}

///|
/// Add a text metadata value.
/// The key is normalized to lowercase.
pub fn Metadata::add_text(
  self : Metadata,
  key : String,
  value : String,
) -> Result[Unit, RpcError] {
  match validate_metadata_key(key) {
    Err(err) => Err(err)
    Ok(normalized_key) => {
      if normalized_key.has_suffix("-bin") {
        return Err(
          invalid_argument_error("-bin key requires binary metadata value"),
        )
      }
      let values = self.entries_map.get_or_init(normalized_key, fn() { [] })
      values.push(Text(value))
      Ok(())
    }
  }
}

///|
/// Add a binary metadata value.
/// Binary keys must end with `-bin`.
pub fn Metadata::add_binary(
  self : Metadata,
  key : String,
  value : Bytes,
) -> Result[Unit, RpcError] {
  match validate_metadata_key(key) {
    Err(err) => Err(err)
    Ok(normalized_key) => {
      if !normalized_key.has_suffix("-bin") {
        return Err(
          invalid_argument_error("binary metadata key must end with -bin"),
        )
      }
      let values = self.entries_map.get_or_init(normalized_key, fn() { [] })
      values.push(Binary(value))
      Ok(())
    }
  }
}

///|
/// Read values for a key after lowercase normalization.
/// Returns an empty array when the key is absent.
pub fn Metadata::get(self : Metadata, key : String) -> Array[MetadataValue] {
  let normalized = normalize_metadata_key(key)
  match self.entries_map.get(normalized) {
    Some(values) => values.copy()
    None => []
  }
}

///|
/// Return all stored entries with normalized lowercase keys.
pub fn Metadata::entries(
  self : Metadata,
) -> Array[(String, Array[MetadataValue])] {
  self.entries_map.to_array().map(entry => (entry.0, entry.1.copy()))
}

///|
fn normalize_metadata_key(key : String) -> String {
  key.to_lower()
}

///|
/// Validate and normalize a metadata key.
///
/// Valid characters are `[0-9a-z_.-]` as defined in the gRPC over HTTP/2 spec:
/// https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md
///   Header-Name → 1*( %x30-39 / %x61-7A / "_" / "-" / "." )
fn validate_metadata_key(key : String) -> Result[String, RpcError] {
  let normalized = normalize_metadata_key(key)
  if normalized.length() == 0 {
    return Err(invalid_argument_error("metadata key must not be empty"))
  }
  for ch in normalized.iter() {
    if not(is_valid_metadata_key_char(ch)) {
      return Err(
        invalid_argument_error(
          "metadata key must match [0-9a-z_.-] per gRPC HTTP/2 spec",
        ),
      )
    }
  }
  Ok(normalized)
}

///|
/// Check whether a character is allowed in a gRPC metadata key.
///
/// Allowed: `0-9` (%x30-39), `a-z` (%x61-7A), `_`, `-`, `.`
fn is_valid_metadata_key_char(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0x30 && code <= 0x39) || // 0-9
  (code >= 0x61 && code <= 0x7A) || // a-z
  code == 0x5F || // _
  code == 0x2D || // -
  code == 0x2E // .
}

///|
/// Decompose a `Metadata` into the raw text/binary arrays expected by the backend.
///
/// Per the gRPC spec, a `-bin` key only contains `Binary` values and a non-`-bin`
/// key only contains `Text` values.  The `add_text` / `add_binary` validation
/// guarantees this invariant, so each key maps to exactly one of the two arrays.
fn metadata_to_backend(
  metadata : Metadata,
) -> (Array[(String, Array[String])], Array[(String, Array[Bytes])]) {
  let text_entries : Array[(String, Array[String])] = []
  let binary_entries : Array[(String, Array[Bytes])] = []
  for _, entry in metadata.entries() {
    let key = entry.0
    let values = entry.1
    if key.has_suffix("-bin") {
      let binaries : Array[Bytes] = []
      for value in values {
        guard value is Binary(bytes) else { continue }
        binaries.push(bytes)
      }
      binary_entries.push((key, binaries))
    } else {
      let texts : Array[String] = []
      for value in values {
        guard value is Text(text) else { continue }
        texts.push(text)
      }
      text_entries.push((key, texts))
    }
  }
  (text_entries, binary_entries)
}

///|
/// Reconstruct a `Metadata` from the raw arrays returned by the backend.
///
/// NOTE: Validation errors from `add_text` / `add_binary` are intentionally
/// ignored here because backend-supplied keys are assumed to be well-formed.
/// If this assumption is violated, the offending entries are silently dropped.
/// Consider adding debug-level logging if this becomes a problem in practice.
fn metadata_from_backend(
  text_entries : Array[(String, Array[String])],
  binary_entries : Array[(String, Array[Bytes])],
) -> Metadata {
  let metadata = Metadata::new()
  for _, entry in text_entries {
    let key = entry.0
    let values = entry.1
    for value in values {
      ignore(metadata.add_text(key, value))
    }
  }
  for _, entry in binary_entries {
    let key = entry.0
    let values = entry.1
    for value in values {
      ignore(metadata.add_binary(key, value))
    }
  }
  metadata
}
