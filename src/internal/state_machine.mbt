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
pub struct FinishOnce[T] {
  mut value : T?
}

///|
pub fn[T] FinishOnce::new() -> FinishOnce[T] {
  { value: None }
}

///|
pub fn[T] FinishOnce::is_done(self : FinishOnce[T]) -> Bool {
  self.value is Some(_)
}

///|
pub fn[T] FinishOnce::finish(self : FinishOnce[T], value : T) -> Bool {
  if self.value is Some(_) {
    false
  } else {
    self.value = Some(value)
    true
  }
}

///|
pub fn[T] FinishOnce::get(self : FinishOnce[T]) -> T? {
  self.value
}
