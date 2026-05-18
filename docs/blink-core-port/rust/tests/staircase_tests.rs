//! Parity tests for AdaptiveStaircase — port of the Swift + C# tests.
//!
//! These verify the Rust implementation matches the reference behavior in
//! `blink-windows/src/Blink.Core/GaborExercise/AdaptiveStaircase.cs`.

use blink_core::staircase::AdaptiveStaircase;

#[test]
fn initial_contrast_is_start_value() {
    let s = AdaptiveStaircase::new(0.5, 0.05);
    assert_eq!(s.current_contrast(), 0.5);
}

#[test]
fn one_correct_does_not_step_down() {
    // 2-down-1-up: needs TWO consecutive correct before contrast decreases.
    let mut s = AdaptiveStaircase::new(0.5, 0.05);
    s.record_response(true);
    assert_eq!(s.current_contrast(), 0.5);
}

#[test]
fn two_consecutive_correct_steps_down() {
    let mut s = AdaptiveStaircase::new(0.5, 0.05);
    s.record_response(true);
    s.record_response(true);
    assert!((s.current_contrast() - 0.45).abs() < 1e-9);
}

#[test]
fn incorrect_steps_up_immediately() {
    let mut s = AdaptiveStaircase::new(0.5, 0.05);
    s.record_response(false);
    assert!((s.current_contrast() - 0.55).abs() < 1e-9);
}

#[test]
fn reversal_halves_step_size() {
    // Down direction, then up direction → reversal. Next time the step
    // should be half (0.025 instead of 0.05).
    let mut s = AdaptiveStaircase::new(0.5, 0.05);
    s.record_response(true);
    s.record_response(true);     // → 0.45, direction = Down
    s.record_response(false);    // → 0.50, reversal recorded
    assert_eq!(s.reversal_count(), 1);
    // After the reversal the step is now 0.025. Two more correct should
    // land at 0.475, not 0.45.
    s.record_response(true);
    s.record_response(true);     // → 0.475
    assert!((s.current_contrast() - 0.475).abs() < 1e-9);
}

#[test]
fn contrast_clamped_to_min() {
    let mut s = AdaptiveStaircase::new(0.02, 0.05);
    s.record_response(true);
    s.record_response(true);
    // Would go to -0.03 but clamps to 0.01
    assert!((s.current_contrast() - 0.01).abs() < 1e-9);
}

#[test]
fn contrast_clamped_to_max() {
    let mut s = AdaptiveStaircase::new(0.97, 0.05);
    s.record_response(false);
    // Would go to 1.02 but clamps to 1.0
    assert!((s.current_contrast() - 1.0).abs() < 1e-9);
}

#[test]
fn threshold_returns_none_below_two_reversals() {
    let s = AdaptiveStaircase::new(0.5, 0.05);
    assert_eq!(s.threshold(), None);
}

#[test]
fn threshold_averages_reversals_when_few() {
    let mut s = AdaptiveStaircase::new(0.5, 0.05);
    // Build up exactly 2 reversals.
    s.record_response(true);
    s.record_response(true);   // down → 0.45
    s.record_response(false);  // up → 0.50, reversal #1
    s.record_response(true);
    s.record_response(true);   // down → 0.475, reversal #2 (was up, now down)
    assert_eq!(s.reversal_count(), 2);
    let t = s.threshold().expect("should have threshold with >= 2 reversals");
    assert!((t - (0.50 + 0.475) / 2.0).abs() < 1e-9);
}

#[test]
fn reset_clears_everything() {
    let mut s = AdaptiveStaircase::new(0.5, 0.05);
    for _ in 0..6 { s.record_response(true); }
    s.reset();
    assert_eq!(s.current_contrast(), 0.5);
    assert_eq!(s.reversal_count(), 0);
    assert!(s.trial_results().is_empty());
}

#[test]
fn trial_results_recorded_in_order() {
    let mut s = AdaptiveStaircase::new(0.5, 0.05);
    s.record_response(true);
    s.record_response(false);
    s.record_response(true);
    let results = s.trial_results();
    assert_eq!(results.len(), 3);
    assert_eq!(results[0].correct, true);
    assert_eq!(results[1].correct, false);
    assert_eq!(results[2].correct, true);
}
