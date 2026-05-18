//! 2-down-1-up adaptive staircase for measuring contrast thresholds.
//!
//! Direct port of `BlinkCore.AdaptiveStaircase` (Swift) and
//! `Blink.Core.GaborExercise.AdaptiveStaircase` (C#). Behavior verified by
//! the parity tests in `tests/staircase_tests.rs`.

use std::os::raw::c_int;

const MIN_CONTRAST: f64 = 0.01;
const MAX_CONTRAST: f64 = 1.0;
const MIN_STEP: f64 = 0.005;

#[derive(Copy, Clone, PartialEq, Debug)]
enum Direction { Up, Down }

#[derive(Copy, Clone, Debug)]
pub struct TrialResult {
    pub contrast: f64,
    pub correct: bool,
}

pub struct AdaptiveStaircase {
    current_contrast: f64,
    step_size: f64,
    consecutive_correct: u32,
    last_direction: Option<Direction>,
    reversals: Vec<f64>,
    trial_results: Vec<TrialResult>,
}

impl AdaptiveStaircase {
    pub fn new(start_contrast: f64, initial_step: f64) -> Self {
        Self {
            current_contrast: start_contrast,
            step_size: initial_step,
            consecutive_correct: 0,
            last_direction: None,
            reversals: Vec::new(),
            trial_results: Vec::new(),
        }
    }

    pub fn current_contrast(&self) -> f64 { self.current_contrast }
    pub fn reversal_count(&self) -> usize { self.reversals.len() }
    pub fn trial_results(&self) -> &[TrialResult] { &self.trial_results }

    pub fn record_response(&mut self, correct: bool) {
        self.trial_results.push(TrialResult {
            contrast: self.current_contrast,
            correct,
        });

        if correct {
            self.consecutive_correct += 1;
            if self.consecutive_correct >= 2 {
                self.consecutive_correct = 0;
                self.current_contrast = (self.current_contrast - self.step_size).max(MIN_CONTRAST);
                if self.last_direction == Some(Direction::Up) {
                    self.reversals.push(self.current_contrast);
                    self.step_size = (self.step_size * 0.5).max(MIN_STEP);
                }
                self.last_direction = Some(Direction::Down);
            }
        } else {
            self.consecutive_correct = 0;
            self.current_contrast = (self.current_contrast + self.step_size).min(MAX_CONTRAST);
            if self.last_direction == Some(Direction::Down) {
                self.reversals.push(self.current_contrast);
                self.step_size = (self.step_size * 0.5).max(MIN_STEP);
            }
            self.last_direction = Some(Direction::Up);
        }
    }

    pub fn threshold(&self) -> Option<f64> {
        let n = self.reversals.len();
        if n >= 6 {
            let last6: f64 = self.reversals.iter().rev().take(6).sum();
            Some(last6 / 6.0)
        } else if n >= 2 {
            let sum: f64 = self.reversals.iter().sum();
            Some(sum / n as f64)
        } else {
            None
        }
    }

    pub fn reset(&mut self) {
        self.current_contrast = 0.5;
        self.step_size = 0.05;
        self.consecutive_correct = 0;
        self.last_direction = None;
        self.reversals.clear();
        self.trial_results.clear();
    }
}

// ---- C ABI ----
//
// Opaque handle pattern: callers allocate via `blink_staircase_new`, call
// methods through the handle, free via `blink_staircase_free`.

#[no_mangle]
pub extern "C" fn blink_staircase_new(start_contrast: f64, initial_step: f64) -> *mut AdaptiveStaircase {
    Box::into_raw(Box::new(AdaptiveStaircase::new(start_contrast, initial_step)))
}

#[no_mangle]
pub extern "C" fn blink_staircase_free(handle: *mut AdaptiveStaircase) {
    if handle.is_null() { return; }
    unsafe { drop(Box::from_raw(handle)); }
}

#[no_mangle]
pub extern "C" fn blink_staircase_record(handle: *mut AdaptiveStaircase, correct: bool) {
    if handle.is_null() { return; }
    unsafe { (*handle).record_response(correct); }
}

#[no_mangle]
pub extern "C" fn blink_staircase_current_contrast(handle: *const AdaptiveStaircase) -> f64 {
    if handle.is_null() { return 0.0; }
    unsafe { (*handle).current_contrast() }
}

#[no_mangle]
pub extern "C" fn blink_staircase_reversal_count(handle: *const AdaptiveStaircase) -> c_int {
    if handle.is_null() { return 0; }
    unsafe { (*handle).reversal_count() as c_int }
}

/// Returns 0 + writes the threshold to `out` if available, or returns -1
/// (insufficient data, `out` untouched).
#[no_mangle]
pub extern "C" fn blink_staircase_threshold(handle: *const AdaptiveStaircase, out: *mut f64) -> c_int {
    if handle.is_null() || out.is_null() { return -1; }
    unsafe {
        match (*handle).threshold() {
            Some(t) => { *out = t; 0 }
            None => -1
        }
    }
}

#[no_mangle]
pub extern "C" fn blink_staircase_reset(handle: *mut AdaptiveStaircase) {
    if handle.is_null() { return; }
    unsafe { (*handle).reset(); }
}
