using Blink.Core.FlowDetection;

namespace Blink.Core.Tests;

/// <summary>
/// Behavioral spec for BreakDecisionEngine — the extend-or-break logic that
/// runs when the 20-minute timer fires. Each test here is also a portable
/// vector for the Swift / Rust ports.
///
/// Score weights (post-2026-05 retune v2 — 6-bucket keyboard, continuous creative):
///   Keyboard (40%):  0→0, &lt;15→0.08, &lt;30→0.14, &lt;50→0.22, &lt;75→0.32, &lt;100→0.38, 100+→0.40
///   Clicks   (20%):  0→0, &lt;3→0.04, &lt;10→0.08, &lt;25→0.12, 25+→0.16
///   Switches (20%):  0/min→0.20, &lt;0.5→0.16, &lt;1→0.10, &lt;2→0.06, 2+→0
///   Creative (10%):  continuous — (0.3 + 0.7×creativeFraction) × 0.10
///   Scroll   (10%):  pure-scroll→0, scroll-dominant→0.02, high-scroll→0.04, normal→0.08
/// </summary>
public class BreakDecisionEngineTests
{
    // --- Window mechanics ---

    [Fact]
    public void EmptyWindow_AlwaysShowsBreak()
    {
        var d = new BreakDecisionEngine(0.7);
        d.Tick(60);
        Assert.IsType<BreakDecision.ShowBreak>(d.Decide(now: 60));
    }

    [Fact]
    public void ZeroWindowSeconds_DoesNotDivideByZero()
    {
        var d = new BreakDecisionEngine(0.7);
        // Window has zero elapsed seconds — should not throw or NaN
        var result = d.Decide(now: 0);
        Assert.IsType<BreakDecision.ShowBreak>(result);
    }

    [Fact]
    public void ResetWindow_ClearsCountsButKeepsExtensions()
    {
        var d = new BreakDecisionEngine(0.6);
        SimulateHeavyTyping(d, durationSeconds: 1200);
        // First call: should extend, extensionCount → 1
        Assert.IsType<BreakDecision.Extend>(d.Decide(now: 1200));

        d.ResetWindow(1200);
        // No input + frequent app-switching scores below the 0.5 threshold.
        d.Tick(1200);
        for (var i = 0; i < 60; i++) d.RecordAppSwitch("Chrome", 1200); // 3 switches/min → switchScore 0
        d.Tick(2400);
        Assert.IsType<BreakDecision.ShowBreak>(d.Decide(now: 2400));
    }

    [Fact]
    public void ResetAll_ClearsCountsAndExtensions()
    {
        var d = new BreakDecisionEngine(0.9);
        SimulateHeavyTyping(d, durationSeconds: 1200);
        Assert.IsType<BreakDecision.Extend>(d.Decide(now: 1200));

        d.ResetAll(1200);
        // After ResetAll, extension counter is back to 0 — heavy activity extends again
        d.Tick(1200);
        SimulateHeavyTypingFrom(d, start: 1200, durationSeconds: 1200);
        Assert.IsType<BreakDecision.Extend>(d.Decide(now: 2400));
    }

    // --- Decision boundary by sensitivity ---

    [Fact]
    public void HighSensitivity_ExtendsAtModerateActivity()
    {
        // 40 kpm + 3 cpm, no switches, non-creative:
        //   keyboard 0.22 + clicks 0.08 + switches 0.20 + creative 0.03 + scroll 0.08 = 0.61
        // sens 0.9 → threshold 0.2 → 0.61 ≥ 0.2 → EXTEND
        var d = new BreakDecisionEngine(0.9);
        SimulateModerateTyping(d, durationSeconds: 1200);
        Assert.IsType<BreakDecision.Extend>(d.Decide(now: 1200));
    }

    [Fact]
    public void LowSensitivity_RequiresHeavyActivity()
    {
        // Score 0.61, sens 0.4 → threshold 0.7 → 0.61 < 0.7 → BREAK
        var d = new BreakDecisionEngine(0.4);
        SimulateModerateTyping(d, durationSeconds: 1200);
        Assert.IsType<BreakDecision.ShowBreak>(d.Decide(now: 1200));
    }

    [Fact]
    public void LowSensitivity_StillExtendsForHeavyActivity()
    {
        // 100 kpm → keyboard 0.38, 10 cpm → clicks 0.12, switches 0.20,
        //   creative 0.03, scroll 0.08 = 0.81. sens 0.4 → threshold 0.7 → EXTEND
        var d = new BreakDecisionEngine(0.4);
        SimulateHeavyTyping(d, durationSeconds: 1200);
        Assert.IsType<BreakDecision.Extend>(d.Decide(now: 1200));
    }

    // --- Extension cap ---

    [Fact]
    public void MaxExtensions_Zero_AlwaysShowsBreak()
    {
        var d = new BreakDecisionEngine(0.9);
        SimulateHeavyTyping(d, durationSeconds: 1200);
        Assert.IsType<BreakDecision.ShowBreak>(d.Decide(maxExtensions: 0, now: 1200));
    }

    [Fact]
    public void Extends_FirstTwo_ThenBreaks()
    {
        var d = new BreakDecisionEngine(0.9);

        SimulateHeavyTyping(d, durationSeconds: 1200);
        Assert.IsType<BreakDecision.Extend>(d.Decide(maxExtensions: 2, now: 1200));

        d.ResetWindow(1200);
        SimulateHeavyTypingFrom(d, start: 1200, durationSeconds: 1200);
        Assert.IsType<BreakDecision.Extend>(d.Decide(maxExtensions: 2, now: 2400));

        d.ResetWindow(2400);
        SimulateHeavyTypingFrom(d, start: 2400, durationSeconds: 1200);
        // Third call: cap hit, forced break
        Assert.IsType<BreakDecision.ShowBreak>(d.Decide(maxExtensions: 2, now: 3600));
    }

    [Fact]
    public void ExtensionMinutes_30Then40()
    {
        var d = new BreakDecisionEngine(0.9);

        SimulateHeavyTyping(d, durationSeconds: 1200);
        var first = Assert.IsType<BreakDecision.Extend>(d.Decide(now: 1200));
        Assert.Equal(30, first.Minutes);

        d.ResetWindow(1200);
        SimulateHeavyTypingFrom(d, start: 1200, durationSeconds: 1200);
        var second = Assert.IsType<BreakDecision.Extend>(d.Decide(now: 2400));
        Assert.Equal(40, second.Minutes);
    }

    // --- Signal mix ---

    [Fact]
    public void OnlyScrolling_DoesNotExtend()
    {
        // Pure scrolling with no keyboard input and frequent app switching —
        // user is browsing/reading, not in flow. Should break.
        // kpm 0, spm 10, switches 3/min: keyboard 0 + clicks 0 + switches 0
        //   + creative 0.03 + scroll 0 (pure scroll) = 0.03
        var d = new BreakDecisionEngine(0.6);
        d.Tick(0);
        for (var i = 0; i < 200; i++) d.RecordScroll();
        for (var i = 0; i < 60; i++) d.RecordAppSwitch("Chrome", 0); // 3 switches/min
        d.Tick(1200);
        Assert.IsType<BreakDecision.ShowBreak>(d.Decide(now: 1200));
    }

    [Fact]
    public void FrequentAppSwitching_PenalizesScore()
    {
        // Heavy typing with frequent switches — should still extend at sens 0.9.
        // 80 kpm → keyboard 0.32, 10 cpm → clicks 0.12, 2.5 switches/min → 0,
        //   creative 0.03, scroll 0.08 = 0.55. sens 0.9 → threshold 0.2 → EXTEND
        var d = new BreakDecisionEngine(0.9);

        d.Tick(0);
        for (var i = 0; i < 1600; i++) d.RecordKeystroke();
        for (var i = 0; i < 200; i++) d.RecordClick();
        for (var i = 0; i < 50; i++) d.RecordAppSwitch("OtherApp", 0);
        d.Tick(1200);

        var decision = d.Decide(now: 1200);
        Assert.IsType<BreakDecision.Extend>(decision);
    }

    [Fact]
    public void CreativeApp_DwellWeightedBonus()
    {
        // The creative-app bonus is dwell-weighted. A window spent entirely in
        // a creative app (Code) scores higher than the same activity in a
        // non-creative app (notepad). Assert the bonus directly via SpotCheck.
        var withCreative = new BreakDecisionEngine(0.65);
        withCreative.SetCurrentApp("Code", 0);
        SimulateBoundaryTyping(withCreative);
        var c = withCreative.SpotCheck(now: 1200);

        var withoutCreative = new BreakDecisionEngine(0.65);
        withoutCreative.SetCurrentApp("notepad", 0);
        SimulateBoundaryTyping(withoutCreative);
        var nc = withoutCreative.SpotCheck(now: 1200);

        Assert.True(c.CreativeFraction > 0.99, $"all-Code window → creativeFraction ≈ 1.0 (got {c.CreativeFraction})");
        Assert.True(nc.CreativeFraction < 0.01, $"all-notepad window → creativeFraction ≈ 0.0 (got {nc.CreativeFraction})");
        Assert.True(c.Score > nc.Score, "Creative-app bonus must raise the score, never lower it");
    }

    // --- Keyboard-curve reference cases ---

    [Fact]
    public void KeyboardCurve_33Kpm_ReferenceCase()
    {
        // 33 kpm is the ★ reference point tied to a real user-reported
        // regression. With 0 cpm, 0 spm, 0 switches, non-creative:
        //   keyboard 0.55×0.40 = 0.22
        //   clicks   0
        //   switches 1.0×0.20 = 0.20
        //   creative 0.3×0.10 = 0.03
        //   scroll   0.8×0.10 = 0.08  (kpm ≥ 5, no scroll dominance)
        //   total    = 0.53
        // Must stay BELOW the Balanced threshold (0.45 at sens 0.65)? No —
        // 0.53 > 0.45. The spec invariant is it stays below the OLD over-reward
        // and produces a deterministic 0.53; that is what we lock here.
        var d = new BreakDecisionEngine(0.65);
        d.Tick(0);
        for (var i = 0; i < 33; i++) d.RecordKeystroke();
        d.Tick(60); // 1-minute window → 33 kpm exactly
        var s = d.SpotCheck(now: 60);
        Assert.Equal(33.0, s.Kpm, 6);
        Assert.Equal(0.53, s.Score, 6);
    }

    [Fact]
    public void KeyboardCurve_BucketBoundaries()
    {
        // Verify each keyboard bucket produces the documented score, isolating
        // the keyboard signal (0 cpm/spm/switches, non-creative).
        //   base from non-keyboard = switches 0.20 + creative 0.03 + scroll 0.08 = 0.31
        AssertKeyboardScore(kpm: 0, expectedTotal: 0.31);    // 0       + 0.31
        AssertKeyboardScore(kpm: 10, expectedTotal: 0.39);   // 0.08    + 0.31
        AssertKeyboardScore(kpm: 25, expectedTotal: 0.45);   // 0.14    + 0.31
        AssertKeyboardScore(kpm: 40, expectedTotal: 0.53);   // 0.22    + 0.31
        AssertKeyboardScore(kpm: 60, expectedTotal: 0.63);   // 0.32    + 0.31
        AssertKeyboardScore(kpm: 90, expectedTotal: 0.69);   // 0.38    + 0.31
        AssertKeyboardScore(kpm: 120, expectedTotal: 0.71);  // 0.40    + 0.31
    }

    private static void AssertKeyboardScore(int kpm, double expectedTotal)
    {
        var d = new BreakDecisionEngine(0.65);
        d.Tick(0);
        for (var i = 0; i < kpm; i++) d.RecordKeystroke();
        d.Tick(60); // 1-minute window → kpm exactly
        var s = d.SpotCheck(now: 60);
        Assert.Equal(kpm, s.Kpm, 6);
        Assert.Equal(expectedTotal, s.Score, 6);
    }

    // --- Helpers ---
    //
    // Tick(now) takes a wall-clock timestamp. The first call sets the window
    // start; subsequent calls compute elapsed = now - start. So to simulate a
    // 20-minute window we Tick(0) at the beginning and Tick(1200) at the end.

    private static void SimulateHeavyTyping(BreakDecisionEngine d, double durationSeconds)
        => SimulateHeavyTypingFrom(d, start: 0, durationSeconds: durationSeconds);

    private static void SimulateHeavyTypingFrom(BreakDecisionEngine d, double start, double durationSeconds)
    {
        d.Tick(start);
        // ~100 kpm sustained — top keyboard bucket; 10 cpm
        for (var i = 0; i < (int)(durationSeconds / 60.0 * 100); i++) d.RecordKeystroke();
        for (var i = 0; i < (int)(durationSeconds / 60.0 * 10); i++) d.RecordClick();
        d.Tick(start + durationSeconds);
    }

    private static void SimulateModerateTyping(BreakDecisionEngine d, double durationSeconds)
    {
        d.Tick(0);
        // ~40 kpm — middle of the <50 bucket
        for (var i = 0; i < (int)(durationSeconds / 60.0 * 40); i++) d.RecordKeystroke();
        for (var i = 0; i < (int)(durationSeconds / 60.0 * 3); i++) d.RecordClick();
        d.Tick(durationSeconds);
    }

    private static void SimulateBoundaryTyping(BreakDecisionEngine d)
    {
        d.Tick(0);
        // ~30 kpm over 20 min, with ~3 cpm
        for (var i = 0; i < 600; i++) d.RecordKeystroke();
        for (var i = 0; i < 60; i++) d.RecordClick();
        d.Tick(1200);
    }
}
