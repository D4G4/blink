# BlinkCore Port Reference

Companion artifacts for porting the BlinkCore algorithms to additional
languages. **None of this is built by the app.** These files exist to help
keep parallel implementations in sync.

## Layout

```
docs/blink-core-port/
├── swift-tests/    # Drop into the private D4G4/blink-core repo's test target.
│                     Mirrors the new C# tests added in commit 1900c25.
│
└── rust/           # Cargo skeleton for an eventual native-shared-library port.
                      Builds as a static lib + cdylib. AdaptiveStaircase is fully
                      ported as a proof of concept; the rest are stubs.
```

## The dual-implementation problem

BlinkCore exists as:
- **Swift** in the private `D4G4/blink-core` repo (consumed by macOS)
- **C#** in this public repo at `blink-windows/src/Blink.Core/` (consumed by Windows)

Every algorithm change today must be made in both. The C# version effectively
publishes the algorithm — anyone reading the public Windows code can deduce
what the private Swift package contains.

Two paths to fix this:

1. **Move C# Blink.Core into the private repo too.** Same dual-edit burden
   but the C# port stops being a public reference implementation.
2. **Replace both with a Rust core + thin language bindings.** Single source
   of truth. Multi-week rewrite + ongoing FFI maintenance.

The Swift tests here are immediate work toward path 1: they raise the bar
for "did I keep both sides in sync?" The Rust skeleton is a bounded
exploration of path 2.

## What's covered by the new tests (from the most recent expansion)

Added in `blink-windows/src/Blink.Core.Tests/` and ported here:

| Test class | Tests added | Why it matters |
|---|---|---|
| `BreakDecisionEngineTests` | 13 | First coverage — the core extend-or-break scorer |
| `BlinkEngineTests` | 18 | First coverage of the orchestrator |
| `TimerStateMachineTests` | +6 | Caught the `Reset()` / `TimerDuration` bug |
| `FlowStateMachineTests` | +6 | Idle/meeting boundary cases |

The Timer bug fix: `Reset(duration)` previously only updated
`RemainingSeconds`, leaving `TimerDuration` hardcoded to 1200. The engine
would then fire `OnTimerUpdate(remaining=600, total=1200)` during a
10-minute extension, making any progress bar start at 50%. Fixed by making
`TimerDuration` settable via `Reset()` / `ResetAfterBreak()`. **This same
bug almost certainly exists in the Swift BlinkCore — check there too.**

## How to use the Swift tests

The xctest file names match the C# files. Drop them into
`Tests/BlinkCoreTests/` in the private `blink-core` repo. Test methods
follow the convention:

```
C#:    [Fact] public void XxxYyy()
Swift: func test_XxxYyy()
```

Helper signatures and assertion semantics are the same. Each test method
is independently portable.

## How to use the Rust skeleton

```bash
cd docs/blink-core-port/rust
cargo test            # runs the AdaptiveStaircase tests (mirror of C# tests)
cargo build --release # produces target/release/libblink_core.{dll,dylib,so}
```

Only `staircase.rs` is implemented. The other modules are scaffolding —
they declare types and stub methods so the FFI surface is visible, but the
bodies are `unimplemented!()`. The intent is to give a sense of the work
involved without committing to the full rewrite.

For a real port: pick one module, implement it fully, copy the parity
tests from the C# version into `tests/`, and verify behavior matches. Then
move to the next module.
