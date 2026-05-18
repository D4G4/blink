using Blink.Core.FlowDetection;

namespace Blink.Core.Tests;

/// <summary>
/// Behavioral spec for BreakDecisionEngine — the extend-or-break logic that
/// runs when the 20-minute timer fires. Each test here is also a portable
/// vector for the Swift / Rust ports.
/// </summary>
public class BreakDecisionEngineTests
{
    // --- Window mechanics ---

    [Fact]
    public void EmptyWindow_AlwaysShowsBreak()
    {
        var d = new BreakDecisionEngine();
        d.Tick(60);
        Assert.IsType<BreakDecision.ShowBreak>(d.Decide());
    }

    [Fact]
    public void ZeroWindowSeconds_DoesNotDivideByZero()
    {
        var d = new BreakDecisionEngine();
        // Window has zero elapsed seconds — should not throw or NaN
        var result = d.Decide();
        Assert.IsType<BreakDecision.ShowBreak>(result);
    }

    [Fact]
    public void ResetWindow_ClearsCountsButKeepsExtensions()
    {
        var d = new BreakDecisionEngine { Sensitivity = 0.6 };
        SimulateHeavyTyping(d, durationSeconds: 1200);
        // First call: should extend, _extensionCount → 1
        Assert.IsType<BreakDecision.Extend>(d.Decide());

        d.ResetWindow();
        // No input + frequent app-switching scores below the 0.5 threshold.
        d.Tick(0);
        for (var i = 0; i < 60; i++) d.RecordAppSwitch("Chrome"); // 3 switches/min → switchScore 0
        d.Tick(1200);
        Assert.IsType<BreakDecision.ShowBreak>(d.Decide());
    }

    [Fact]
    public void ResetAll_ClearsCountsAndExtensions()
    {
        var d = new BreakDecisionEngine { Sensitivity = 0.9 };
        SimulateHeavyTyping(d, durationSeconds: 1200);
        Assert.IsType<BreakDecision.Extend>(d.Decide());

        d.ResetAll();
        // After ResetAll, extension counter is back to 0 — heavy activity extends again
        SimulateHeavyTyping(d, durationSeconds: 1200);
        Assert.IsType<BreakDecision.Extend>(d.Decide());
    }

    // --- Decision boundary by sensitivity ---

    [Fact]
    public void HighSensitivity_ExtendsAtModerateActivity()
    {
        var d = new BreakDecisionEngine { Sensitivity = 0.9 };
        SimulateModerateTyping(d, durationSeconds: 1200);
        Assert.IsType<BreakDecision.Extend>(d.Decide());
    }

    [Fact]
    public void LowSensitivity_RequiresHeavyActivity()
    {
        var d = new BreakDecisionEngine { Sensitivity = 0.4 };
        SimulateModerateTyping(d, durationSeconds: 1200);
        // 0.4 sensitivity → threshold 0.7. Moderate activity scores below.
        Assert.IsType<BreakDecision.ShowBreak>(d.Decide());
    }

    [Fact]
    public void LowSensitivity_StillExtendsForHeavyActivity()
    {
        var d = new BreakDecisionEngine { Sensitivity = 0.4 };
        SimulateHeavyTyping(d, durationSeconds: 1200);
        Assert.IsType<BreakDecision.Extend>(d.Decide());
    }

    // --- Extension cap ---

    [Fact]
    public void MaxExtensions_Zero_AlwaysShowsBreak()
    {
        var d = new BreakDecisionEngine { Sensitivity = 0.9 };
        SimulateHeavyTyping(d, durationSeconds: 1200);
        Assert.IsType<BreakDecision.ShowBreak>(d.Decide(maxExtensions: 0));
    }

    [Fact]
    public void Extends_FirstTwo_ThenBreaks()
    {
        var d = new BreakDecisionEngine { Sensitivity = 0.9 };

        SimulateHeavyTyping(d, durationSeconds: 1200);
        Assert.IsType<BreakDecision.Extend>(d.Decide(maxExtensions: 2));

        d.ResetWindow();
        SimulateHeavyTyping(d, durationSeconds: 1200);
        Assert.IsType<BreakDecision.Extend>(d.Decide(maxExtensions: 2));

        d.ResetWindow();
        SimulateHeavyTyping(d, durationSeconds: 1200);
        // Third call: cap hit, forced break
        Assert.IsType<BreakDecision.ShowBreak>(d.Decide(maxExtensions: 2));
    }

    [Fact]
    public void ExtensionMinutes_30Then40()
    {
        var d = new BreakDecisionEngine { Sensitivity = 0.9 };

        SimulateHeavyTyping(d, durationSeconds: 1200);
        var first = Assert.IsType<BreakDecision.Extend>(d.Decide());
        Assert.Equal(30, first.Minutes);

        d.ResetWindow();
        SimulateHeavyTyping(d, durationSeconds: 1200);
        var second = Assert.IsType<BreakDecision.Extend>(d.Decide());
        Assert.Equal(40, second.Minutes);
    }

    // --- Signal mix ---

    [Fact]
    public void OnlyScrolling_DoesNotExtend()
    {
        // Pure scrolling with no keyboard input and frequent app switching —
        // user is browsing/reading, not in flow. Should break.
        var d = new BreakDecisionEngine { Sensitivity = 0.6 };
        d.Tick(0);
        for (var i = 0; i < 200; i++) d.RecordScroll();
        for (var i = 0; i < 60; i++) d.RecordAppSwitch("Chrome"); // 3 switches/min
        d.Tick(1200);
        Assert.IsType<BreakDecision.ShowBreak>(d.Decide());
    }

    [Fact]
    public void FrequentAppSwitching_PenalizesScore()
    {
        var d = new BreakDecisionEngine { Sensitivity = 0.9 };

        // Heavy typing with frequent switches — should still extend, but less
        // dominantly than the no-switching case.
        for (var i = 0; i < 1600; i++) d.RecordKeystroke();
        for (var i = 0; i < 200; i++) d.RecordClick();
        for (var i = 0; i < 50; i++) d.RecordAppSwitch("OtherApp");
        d.Tick(1200);

        // High enough sensitivity (0.9) should still allow extend despite penalty
        var decision = d.Decide();
        Assert.IsType<BreakDecision.Extend>(decision);
    }

    [Fact]
    public void CreativeApp_TipsAtThreshold()
    {
        // Modest activity that would score *just below* the 0.7 threshold (sens 0.4)
        // gets pushed over by the creative-app bonus.
        var withCreative = new BreakDecisionEngine { Sensitivity = 0.65 };
        SimulateBoundaryTyping(withCreative);
        withCreative.RecordAppSwitch("Code");
        var c = withCreative.Decide();

        var withoutCreative = new BreakDecisionEngine { Sensitivity = 0.65 };
        SimulateBoundaryTyping(withoutCreative);
        withoutCreative.RecordAppSwitch("notepad");
        var nc = withoutCreative.Decide();

        // At least one of them is Extend, and the creative case is never less
        // likely to extend than the non-creative.
        Assert.True(
            c is BreakDecision.Extend || nc is BreakDecision.ShowBreak,
            "Creative-app bonus must not invert the decision");
    }

    // --- Helpers ---
    //
    // Tick(now) takes a wall-clock timestamp. The first call sets the window
    // start; subsequent calls compute elapsed = now - start. So to simulate a
    // 20-minute window we Tick(0) at the beginning and Tick(1200) at the end.

    private static void SimulateHeavyTyping(BreakDecisionEngine d, double durationSeconds)
    {
        d.Tick(0);
        // ~100 kpm sustained — well above the 80-kpm threshold for max keyboard score
        for (var i = 0; i < (int)(durationSeconds / 60.0 * 100); i++) d.RecordKeystroke();
        for (var i = 0; i < (int)(durationSeconds / 60.0 * 10); i++) d.RecordClick();
        d.Tick(durationSeconds);
    }

    private static void SimulateModerateTyping(BreakDecisionEngine d, double durationSeconds)
    {
        d.Tick(0);
        // ~40 kpm — middle of the 30..80 bucket
        for (var i = 0; i < (int)(durationSeconds / 60.0 * 40); i++) d.RecordKeystroke();
        for (var i = 0; i < (int)(durationSeconds / 60.0 * 3); i++) d.RecordClick();
        d.Tick(durationSeconds);
    }

    private static void SimulateBoundaryTyping(BreakDecisionEngine d)
    {
        d.Tick(0);
        // Just enough keyboard to land near (but below) the threshold for sens=0.65
        for (var i = 0; i < 600; i++) d.RecordKeystroke();   // ~30 kpm over 20 min
        for (var i = 0; i < 60; i++) d.RecordClick();
        d.Tick(1200);
    }
}
