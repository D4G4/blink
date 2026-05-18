//! STUB. The orchestrator. See `blink-windows/src/Blink.Core/BlinkEngine.cs`.
//!
//! This is the hardest module to port over FFI because of the callbacks:
//! `OnShowBreak`, `OnShowExtendToast`, `OnTimerUpdate`, `OnStateChange`.
//! Each becomes a C function pointer + context pointer passed from the host
//! language. The host is responsible for keeping the context alive for the
//! engine's lifetime.

#![allow(dead_code)]

#[derive(Copy, Clone, PartialEq, Debug)]
#[repr(C)]
pub enum DisplayState { Working, Away, Meeting, OnBreak }

/// Callback shapes (C ABI). The host language passes a function pointer and
/// a context pointer (e.g. a Box::into_raw'd object or a GC handle).
pub type OnShowBreakFn = extern "C" fn(ctx: *mut std::ffi::c_void, break_number: u32);
pub type OnShowExtendToastFn = extern "C" fn(ctx: *mut std::ffi::c_void, reason: *const u8, reason_len: usize);
pub type OnTimerUpdateFn = extern "C" fn(ctx: *mut std::ffi::c_void, remaining: f64, total: f64);
pub type OnStateChangeFn = extern "C" fn(ctx: *mut std::ffi::c_void, state: DisplayState);

pub struct BlinkEngine {
    // Sub-engines
    timer: crate::timer_state_machine::TimerStateMachine,
    state_machine: crate::flow_state_machine::FlowStateMachine,
    decision_engine: crate::break_decision_engine::BreakDecisionEngine,

    // Callbacks
    on_show_break: Option<OnShowBreakFn>,
    on_show_extend: Option<OnShowExtendToastFn>,
    on_timer_update: Option<OnTimerUpdateFn>,
    on_state_change: Option<OnStateChangeFn>,
    callback_ctx: *mut std::ffi::c_void,

    sensitivity: f64,
    max_wall_clock_seconds: f64,

    // Per-input timestamps as Unix-millis (lossless across FFI vs DateTime)
    last_keystroke_ms: Option<u64>,
    last_click_ms: Option<u64>,
    last_scroll_ms: Option<u64>,
    last_app_switch_ms: Option<u64>,

    break_pending: bool,
    break_pending_since_ms: Option<u64>,
    consecutive_breaks: u32,
    last_break_ended_at_ms: Option<u64>,
    engine_start_time_ms: Option<u64>,
    is_on_break: bool,
    mic_active: bool,
    camera_active: bool,
    video_playing: bool,
}

impl BlinkEngine {
    pub fn new() -> Self {
        Self {
            timer: crate::timer_state_machine::TimerStateMachine::new(),
            state_machine: crate::flow_state_machine::FlowStateMachine::new(),
            decision_engine: crate::break_decision_engine::BreakDecisionEngine::new(),
            on_show_break: None,
            on_show_extend: None,
            on_timer_update: None,
            on_state_change: None,
            callback_ctx: std::ptr::null_mut(),
            sensitivity: 0.7,
            max_wall_clock_seconds: 2400.0,
            last_keystroke_ms: None,
            last_click_ms: None,
            last_scroll_ms: None,
            last_app_switch_ms: None,
            break_pending: false,
            break_pending_since_ms: None,
            consecutive_breaks: 0,
            last_break_ended_at_ms: None,
            engine_start_time_ms: None,
            is_on_break: false,
            mic_active: false,
            camera_active: false,
            video_playing: false,
        }
    }

    pub fn tick(&mut self, _now_ms: u64) {
        unimplemented!("port the Tick orchestration from C# / Swift")
    }

    pub fn record_keystroke(&mut self, _now_ms: u64) { unimplemented!() }
    pub fn record_click(&mut self, _now_ms: u64) { unimplemented!() }
    pub fn record_scroll(&mut self, _now_ms: u64) { unimplemented!() }
    pub fn record_app_switch(&mut self, _now_ms: u64, _process_name: &str) { unimplemented!() }

    pub fn user_took_break(&mut self, _now_ms: u64) { unimplemented!() }
    pub fn user_skipped_break(&mut self, _now_ms: u64) { unimplemented!() }
    pub fn user_snoozed(&mut self, _minutes: u32) { unimplemented!() }
}

// TODO: Full C ABI surface — handle lifecycle, input recording, ticks,
// callback registration. Notably, the host must keep callback_ctx alive
// for the lifetime of the handle and free it after blink_engine_free.
