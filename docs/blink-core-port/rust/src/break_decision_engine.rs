//! STUB. See `blink-windows/src/Blink.Core/FlowDetection/BreakDecisionEngine.cs`.

#![allow(dead_code)]

#[derive(Debug, PartialEq)]
pub enum BreakDecision {
    ShowBreak,
    Extend { minutes: u32, reason: String },
}

pub struct BreakDecisionEngine {
    sensitivity: f64,
    keystroke_count: u32,
    click_count: u32,
    scroll_count: u32,
    app_switch_count: u32,
    window_seconds: f64,
    window_start_time: Option<f64>,
    extension_count: u32,
    current_app: Option<String>,
}

impl BreakDecisionEngine {
    pub fn new() -> Self {
        Self {
            sensitivity: 0.7,
            keystroke_count: 0,
            click_count: 0,
            scroll_count: 0,
            app_switch_count: 0,
            window_seconds: 0.0,
            window_start_time: None,
            extension_count: 0,
            current_app: None,
        }
    }

    pub fn sensitivity(&self) -> f64 { self.sensitivity }
    pub fn set_sensitivity(&mut self, v: f64) { self.sensitivity = v; }

    pub fn record_keystroke(&mut self) { self.keystroke_count += 1; }
    pub fn record_click(&mut self) { self.click_count += 1; }
    pub fn record_scroll(&mut self) { self.scroll_count += 1; }

    pub fn record_app_switch(&mut self, process_name: &str) {
        self.app_switch_count += 1;
        self.current_app = Some(process_name.to_string());
    }

    pub fn tick(&mut self, now: f64) {
        if self.window_start_time.is_none() {
            self.window_start_time = Some(now);
        }
        self.window_seconds = now - self.window_start_time.unwrap();
    }

    pub fn decide(&mut self, _max_extensions: u32) -> BreakDecision {
        unimplemented!("port the scoring buckets + threshold from C# / Swift")
    }

    pub fn reset_window(&mut self) {
        self.keystroke_count = 0;
        self.click_count = 0;
        self.scroll_count = 0;
        self.app_switch_count = 0;
        self.window_seconds = 0.0;
        self.window_start_time = None;
    }

    pub fn reset_all(&mut self) {
        self.reset_window();
        self.extension_count = 0;
    }
}

// TODO: C ABI exports.
