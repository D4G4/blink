using System.Globalization;

namespace Blink.Core.FlowDetection;

/// <summary>
/// Decides whether to show a break or extend the timer.
/// Called when the 20-minute timer fires. Evaluates accumulated signals.
///
/// Port of Swift BlinkCore.BreakDecisionEngine. Windows matches process
/// NAMES (matched via Contains, case-insensitive) where macOS matches bundle
/// IDs (matched via hasPrefix). The scoring curves, thresholds, dwell
/// tracking and SpotCheck output are kept byte-for-byte equivalent.
/// </summary>
public sealed class BreakDecisionEngine
{
    private int _keystrokeCount;
    private int _clickCount;
    private int _scrollCount;
    private int _appSwitchCount;
    private double _windowSeconds;
    private double? _windowStartTime;
    private int _extensionCount;

    // Per-app dwell time accumulated over this window. Updated by
    // RecordAppSwitch (finalizes previous app) and by FinalizeCurrentApp
    // (called from Decide() to credit the still-frontmost app up to now).
    // Replaces the snapshot-at-decision approach so the creative-app bonus
    // reflects time actually spent, not just whatever app happened to be
    // frontmost when the timer fired.
    private readonly Dictionary<string, double> _dwellByApp = new();
    private string? _currentAppBundleID;
    private double? _currentAppStartTime;

    /// <summary>
    /// Sensitivity (0.4–0.9) — higher = more likely to extend. Required at
    /// construction; BlinkCore has no default.
    /// </summary>
    public double Sensitivity { get; set; }

    public BreakDecisionEngine(double sensitivity)
    {
        Sensitivity = sensitivity;
    }

    // MARK: - Ingest signals

    public void RecordKeystroke() => _keystrokeCount++;
    public void RecordClick() => _clickCount++;
    public void RecordScroll() => _scrollCount++;

    public void RecordAppSwitch(string processName, double? now = null)
    {
        var nowTime = now ?? NowSeconds();
        // Credit the previous app's dwell up to this moment.
        if (_currentAppBundleID != null && _currentAppStartTime.HasValue)
            AddDwell(_currentAppBundleID, Math.Max(0, nowTime - _currentAppStartTime.Value));
        _appSwitchCount++;
        _currentAppBundleID = processName;
        _currentAppStartTime = nowTime;
    }

    public void SetCurrentApp(string processName, double? now = null)
    {
        var nowTime = now ?? NowSeconds();
        // Same dwell-tracking semantics as RecordAppSwitch but without
        // incrementing the switch counter — used at session start.
        if (_currentAppBundleID != null && _currentAppStartTime.HasValue)
            AddDwell(_currentAppBundleID, Math.Max(0, nowTime - _currentAppStartTime.Value));
        _currentAppBundleID = processName;
        _currentAppStartTime = nowTime;
    }

    /// <summary>
    /// Finalize the currently-frontmost app's dwell up to <paramref name="now"/>
    /// and reset the start time so further finalize calls don't double-count.
    /// </summary>
    private void FinalizeCurrentApp(double now)
    {
        if (_currentAppBundleID == null || !_currentAppStartTime.HasValue) return;
        AddDwell(_currentAppBundleID, Math.Max(0, now - _currentAppStartTime.Value));
        _currentAppStartTime = now;
    }

    private void AddDwell(string app, double seconds)
    {
        _dwellByApp[app] = (_dwellByApp.TryGetValue(app, out var v) ? v : 0) + seconds;
    }

    /// <summary>Call on each tick to update the window duration.</summary>
    public void Tick(double now)
    {
        _windowStartTime ??= now;
        _windowSeconds = now - (_windowStartTime ?? now);
    }

    // MARK: - Density metrics

    private double KeystrokesPerMinute => _windowSeconds > 0 ? _keystrokeCount / (_windowSeconds / 60.0) : 0;
    private double ClicksPerMinute => _windowSeconds > 0 ? _clickCount / (_windowSeconds / 60.0) : 0;
    private double ScrollsPerMinute => _windowSeconds > 0 ? _scrollCount / (_windowSeconds / 60.0) : 0;
    private double AppSwitchesPerMinute => _windowSeconds > 0 ? _appSwitchCount / (_windowSeconds / 60.0) : 0;

    /// <summary>
    /// Fraction of total dwell time spent in creative apps. 0 = none, 1 =
    /// entirely creative. Used to scale the creative-app bonus continuously.
    /// </summary>
    private double CreativeFraction(Func<string, bool> isCreative)
    {
        var total = _dwellByApp.Values.Sum();
        if (total <= 0) return 0;
        var creative = _dwellByApp.Where(kv => isCreative(kv.Key)).Sum(kv => kv.Value);
        return creative / total;
    }

    /// <summary>Total seconds spent in creative apps this window.</summary>
    private double CreativeSeconds(Func<string, bool> isCreative)
        => _dwellByApp.Where(kv => isCreative(kv.Key)).Sum(kv => kv.Value);

    // MARK: - Decide

    /// <summary>
    /// Called when the timer fires. Evaluates all collected signals.
    /// <paramref name="maxExtensions"/>: 0 = never extend, 1 = Balanced, 2 = Deep Work.
    /// <paramref name="now"/> is used to finalize the currently-frontmost app's
    /// dwell so the creative-app bonus reflects total time spent.
    /// </summary>
    public BreakDecision Decide(int maxExtensions = 2, double? now = null)
    {
        var nowTime = now ?? NowSeconds();
        FinalizeCurrentApp(nowTime);

        var kpm = KeystrokesPerMinute;
        var cpm = ClicksPerMinute;
        var spm = ScrollsPerMinute;
        var switches = AppSwitchesPerMinute;
        var creativeFraction = CreativeFraction(IsCreativeApp);

        // No extensions allowed (Eye Health) or already used all extensions
        if (maxExtensions == 0 || _extensionCount >= maxExtensions)
            return new BreakDecision.ShowBreak();

        var score = ComputeScore(kpm, cpm, spm, switches, creativeFraction);
        var threshold = 1.1 - Sensitivity;

        if (score >= threshold)
        {
            _extensionCount++;
            var minutes = _extensionCount == 1 ? 30 : 40;
            return new BreakDecision.Extend(minutes, "Focused");
        }

        return new BreakDecision.ShowBreak();
    }

    // MARK: - Score computation
    //
    // Six-bucket keyboard curve (post-2026-05 retune v2). See the macOS
    // BreakDecisionEngine.swift for the full curve-shape rationale + history.
    //   Keyboard rhythm        40%   primary signal
    //   Click rhythm           20%   secondary engagement
    //   App-switch frequency   20%   low switching = focused
    //   Creative-app bonus     10%   IDE / Figma / terminal / etc.
    //   Scroll-vs-work signal  10%   penalizes scroll-dominant patterns

    private static double ComputeScore(double kpm, double cpm, double spm, double switches, double creativeFraction)
    {
        double score = 0;

        // Keyboard (40%) — six-bucket curve.
        double keyboardScore = kpm switch
        {
            0 => 0,
            < 15 => 0.20,   // barely typing
            < 30 => 0.35,   // messaging / slow typing
            < 50 => 0.55,   // active but not deep ← 33 kpm
            < 75 => 0.80,   // steady working
            < 100 => 0.95,  // focused coding
            _ => 1.0,       // deep flow / heads-down
        };
        score += keyboardScore * 0.40;

        // Clicks (20%) — saturate below 1.0 so clicks alone don't dominate.
        double clickScore = cpm switch
        {
            0 => 0,
            < 3 => 0.2,
            < 10 => 0.4,
            < 25 => 0.6,
            _ => 0.8,
        };
        score += clickScore * 0.20;

        // App switching (20%, inverted) — low switching = focused.
        double switchScore = switches switch
        {
            0 => 1.0,
            < 0.5 => 0.8,
            < 1 => 0.5,
            < 2 => 0.3,
            _ => 0,
        };
        score += switchScore * 0.20;

        // Creative app bonus (10%) — continuous, dwell-weighted. Linear
        // interpolation between 0.3 (entirely non-creative) and 1.0 (entirely
        // creative) based on the fraction of dwell time in creative apps.
        score += (0.3 + 0.7 * creativeFraction) * 0.10;

        // Scroll-vs-work signal (10%) — penalize scroll-dominant patterns.
        double scrollWorkScore;
        if (kpm < 5 && spm >= 5)
            scrollWorkScore = 0.0;                          // pure scrolling feed
        else if (spm > kpm * 1.5 && spm > 20)
            scrollWorkScore = 0.2;                          // scroll-dominant
        else if (spm > 30)
            scrollWorkScore = 0.4;                          // high scroll, balanced typing
        else
            scrollWorkScore = 0.8;                          // normal pattern
        score += scrollWorkScore * 0.10;

        return Math.Min(score, 1.0);
    }

    // MARK: - App classification

    /// <summary>
    /// Process names where being frontmost contributes the creative-app bonus.
    /// Matched via Contains (OrdinalIgnoreCase). Windows uses process names,
    /// NOT macOS bundle IDs.
    ///
    /// Intentionally excluded: AI chat clients (Claude Desktop, ChatGPT). Per
    /// product decision 2026-05, agent-driven sessions are reading-heavy and
    /// SHOULD let breaks fire; they don't get the creative bonus.
    /// </summary>
    private static readonly HashSet<string> CreativeApps = new(StringComparer.OrdinalIgnoreCase)
    {
        // VS Code family
        "Code",            // VS Code / VS Code Insiders
        "devenv",          // Visual Studio

        // AI-first editors
        "Cursor",
        "Windsurf",
        "Zed",
        "Trae",

        // Sublime
        "sublime_text",

        // JetBrains family
        "idea64",          // IntelliJ
        "rider64",         // Rider
        "webstorm64",      // WebStorm
        "pycharm64",       // PyCharm
        "clion64",         // CLion
        "goland64",        // GoLand
        "phpstorm64",      // PhpStorm
        "datagrip64",      // DataGrip
        "rubymine64",      // RubyMine
        "fleet",           // JetBrains Fleet
        "studio64",        // Android Studio

        // Design
        "figma",
        "Photoshop",
        "Illustrator",
        "Premiere",        // Adobe Premiere Pro
        "AfterFX",         // Adobe After Effects

        // Terminals — where vim/neovim/emacs/helix users live
        "WindowsTerminal",
        "powershell",
        "pwsh",
        "cmd",
        "alacritty",
        "wezterm-gui",

        // Apple media (shared product list)
        "FinalCut",
        "Logic",

        // Knowledge work
        "Notion",
        "Obsidian",
        "Linear",
    };

    private static bool IsCreativeApp(string? name) =>
        name != null && CreativeApps.Any(c => name.Contains(c, StringComparison.OrdinalIgnoreCase));

    // MARK: - Reset

    /// <summary>
    /// Reset after a break is taken or dismissed. Preserves the currently-
    /// frontmost app (re-seeds dwell tracking from <paramref name="now"/>) so
    /// the caller need not re-send an app-switch the user didn't trigger.
    /// </summary>
    public void ResetWindow(double? now = null)
    {
        var nowTime = now ?? NowSeconds();
        var preservedApp = _currentAppBundleID;
        _keystrokeCount = 0;
        _clickCount = 0;
        _scrollCount = 0;
        _appSwitchCount = 0;
        _windowSeconds = 0;
        _windowStartTime = null;
        _dwellByApp.Clear();
        _currentAppBundleID = null;
        _currentAppStartTime = null;
        if (preservedApp != null)
        {
            _currentAppBundleID = preservedApp;
            _currentAppStartTime = nowTime;
        }
    }

    /// <summary>Full reset including extension count. Call on idle/walk-away.</summary>
    public void ResetAll(double? now = null)
    {
        ResetWindow(now);
        _extensionCount = 0;
    }

    public int CurrentExtensionCount => _extensionCount;

    // MARK: - Spot check

    /// <summary>
    /// Compute the current score and return a debug summary without affecting
    /// state (no extension count changes). Finalizes the current app's dwell
    /// up to <paramref name="now"/> so creativeFraction is current.
    /// </summary>
    public SpotCheckResult SpotCheck(double? now = null)
    {
        var nowTime = now ?? NowSeconds();
        FinalizeCurrentApp(nowTime);
        var kpm = KeystrokesPerMinute;
        var cpm = ClicksPerMinute;
        var spm = ScrollsPerMinute;
        var switches = AppSwitchesPerMinute;
        var creativeFraction = CreativeFraction(IsCreativeApp);
        var creativeSeconds = CreativeSeconds(IsCreativeApp);
        var score = ComputeScore(kpm, cpm, spm, switches, creativeFraction);
        var threshold = 1.1 - Sensitivity;
        return new SpotCheckResult(
            score, threshold, score >= threshold,
            kpm, cpm, spm, switches,
            creativeFraction, creativeSeconds,
            _currentAppBundleID, _windowSeconds, _extensionCount);
    }

    private static double NowSeconds() =>
        ((DateTimeOffset)DateTime.UtcNow).ToUnixTimeMilliseconds() / 1000.0;

    /// <summary>
    /// Snapshot of the flow score + signals, used by the app's debug toast.
    /// Port of Swift BreakDecisionEngine.SpotCheck.
    /// </summary>
    public readonly record struct SpotCheckResult(
        double Score,
        double Threshold,
        bool WouldExtend,
        double Kpm,
        double Cpm,
        double Spm,
        double AppSwitchesPerMinute,
        double CreativeFraction,
        double CreativeSeconds,
        string? CurrentApp,
        double WindowSeconds,
        int ExtensionCount)
    {
        private static string F(double v, string fmt) => v.ToString(fmt, CultureInfo.InvariantCulture);

        /// <summary>One-liner for the menu bar.</summary>
        public string Summary =>
            $"Score: {F(Score, "0.00")} (threshold: {F(Threshold, "0.00")}) → {(WouldExtend ? "EXTEND" : "BREAK")}";

        /// <summary>Full detail for preferences/logs.</summary>
        public override string ToString()
        {
            var verdict = WouldExtend ? "EXTEND" : "BREAK";
            var mins = (int)WindowSeconds / 60;
            var secs = (int)WindowSeconds % 60;
            var creativeMins = (int)CreativeSeconds / 60;
            var creativeSecsRem = (int)CreativeSeconds % 60;
            var creativePct = (int)Math.Round(CreativeFraction * 100);
            return
                $"Score: {F(Score, "0.00")} (threshold: {F(Threshold, "0.00")}) → {verdict}\n" +
                $"Window: {mins}m {secs}s | Extensions used: {ExtensionCount}\n" +
                $"Keyboard: {F(Kpm, "0.0")} kpm\n" +
                $"Clicks: {F(Cpm, "0.0")} cpm\n" +
                $"Scrolls: {F(Spm, "0.0")} spm\n" +
                $"App switches: {F(AppSwitchesPerMinute, "0.0")}/min\n" +
                $"Creative time: {creativeMins}m {creativeSecsRem}s ({creativePct}%)\n" +
                $"App (current): {CurrentApp ?? "none"}";
        }
    }
}

// Decision types
public abstract record BreakDecision
{
    public sealed record ShowBreak() : BreakDecision;
    public sealed record Extend(int Minutes, string Reason) : BreakDecision;
}
