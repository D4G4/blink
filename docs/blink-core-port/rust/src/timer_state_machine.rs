//! STUB. See `blink-windows/src/Blink.Core/Timer/TimerStateMachine.cs`
//! and `BlinkCore.TimerStateMachine` (Swift) for the reference behavior.

#![allow(dead_code)]

pub const DEFAULT_DURATION: f64 = 1200.0;

#[derive(Copy, Clone, PartialEq, Debug)]
#[repr(C)]
pub enum FlowState { Normal, Flow, DeepFlow, Idle, Meeting, BreakPrompted }

pub struct TimerStateMachine {
    pub(crate) remaining_seconds: f64,
    pub(crate) timer_duration: f64,
    pub(crate) is_paused: bool,
    pub(crate) on_break_due: Option<extern "C" fn(*mut std::ffi::c_void)>,
    pub(crate) callback_ctx: *mut std::ffi::c_void,
    pub(crate) break_due_fired: bool,
}

impl TimerStateMachine {
    pub fn new() -> Self {
        Self {
            remaining_seconds: DEFAULT_DURATION,
            timer_duration: DEFAULT_DURATION,
            is_paused: false,
            on_break_due: None,
            callback_ctx: std::ptr::null_mut(),
            break_due_fired: false,
        }
    }

    pub fn tick(&mut self, _flow_state: FlowState, _delta_seconds: f64) {
        unimplemented!("port from Swift / C# TimerStateMachine.Tick")
    }

    pub fn reset(&mut self, duration: f64) {
        // Includes the bug fix: TimerDuration must update.
        self.remaining_seconds = duration;
        self.timer_duration = duration;
        self.is_paused = false;
        self.break_due_fired = false;
    }

    pub fn reset_after_break(&mut self) {
        self.reset(DEFAULT_DURATION);
    }

    pub fn progress(&self) -> f64 {
        if self.timer_duration <= 0.0 { return 1.0; }
        (1.0 - self.remaining_seconds / self.timer_duration).clamp(0.0, 1.0)
    }
}

// TODO: C ABI exports following the same opaque-handle pattern as staircase.rs.
