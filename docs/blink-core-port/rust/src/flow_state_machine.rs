//! STUB. See `blink-windows/src/Blink.Core/FlowDetection/FlowStateMachine.cs`.

#![allow(dead_code)]

pub use crate::timer_state_machine::FlowState;

pub struct FlowStateMachine {
    state: FlowState,
}

impl FlowStateMachine {
    pub fn new() -> Self { Self { state: FlowState::Normal } }
    pub fn state(&self) -> FlowState { self.state }

    pub fn tick(
        &mut self,
        _flow_score: f64,
        _idle_seconds: f64,
        _mic_active: bool,
        _camera_active: bool,
        _now: f64,
    ) {
        unimplemented!("port from Swift / C# FlowStateMachine.Tick")
    }

    pub fn enter_break_prompted(&mut self) { self.state = FlowState::BreakPrompted; }
    pub fn exit_break_prompted(&mut self) { self.state = FlowState::Normal; }
}

// TODO: C ABI exports.
