//! Blink's break-reminder algorithms, packaged as a native shared library.
//!
//! Compiles to:
//! - `libblink_core.dylib` (macOS) — consumed by Swift via a thin bridging header
//! - `blink_core.dll` (Windows) — consumed by C# via `[DllImport]`
//!
//! Each module mirrors the Swift `BlinkCore` package layout. The C ABI exports
//! at the bottom of each module file are the only public surface; the Rust
//! types themselves stay `pub(crate)` to keep the FFI shape explicit.
//!
//! Status:
//! - [x] `staircase` — fully ported, matches the C# behavior
//! - [ ] `timer_state_machine` — stub
//! - [ ] `flow_state_machine` — stub
//! - [ ] `break_decision_engine` — stub
//! - [ ] `blink_engine` — stub (orchestrator, has callback complexity)

pub mod staircase;
pub mod timer_state_machine;
pub mod flow_state_machine;
pub mod break_decision_engine;
pub mod blink_engine;
