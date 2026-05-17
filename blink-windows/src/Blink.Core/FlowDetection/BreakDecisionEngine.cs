namespace Blink.Core.FlowDetection;

/// <summary>
/// Decides whether to show a break or extend the timer.
/// Called when the 20-minute timer fires. Evaluates accumulated signals.
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
    private string? _currentApp;

    public double Sensitivity { get; set; } = 0.7;

    public void RecordKeystroke() => _keystrokeCount++;
    public void RecordClick() => _clickCount++;
    public void RecordScroll() => _scrollCount++;
    public void RecordAppSwitch(string processName)
    {
        _appSwitchCount++;
        _currentApp = processName;
    }

    public void Tick(double now)
    {
        _windowStartTime ??= now;
        _windowSeconds = now - (_windowStartTime ?? now);
    }

    public BreakDecision Decide(int maxExtensions = 2)
    {
        var kpm = _windowSeconds > 0 ? _keystrokeCount / (_windowSeconds / 60.0) : 0;
        var cpm = _windowSeconds > 0 ? _clickCount / (_windowSeconds / 60.0) : 0;
        var spm = _windowSeconds > 0 ? _scrollCount / (_windowSeconds / 60.0) : 0;
        var switches = _windowSeconds > 0 ? _appSwitchCount / (_windowSeconds / 60.0) : 0;
        var isCreative = IsCreativeApp(_currentApp);

        if (maxExtensions == 0 || _extensionCount >= maxExtensions)
            return new BreakDecision.ShowBreak();

        var score = ComputeScore(kpm, cpm, spm, switches, isCreative);
        var threshold = 1.1 - Sensitivity;

        if (score >= threshold)
        {
            _extensionCount++;
            var minutes = _extensionCount == 1 ? 30 : 40;
            return new BreakDecision.Extend(minutes, "Focused");
        }

        return new BreakDecision.ShowBreak();
    }

    private static double ComputeScore(double kpm, double cpm, double spm, double switches, bool isCreative)
    {
        double score = 0;

        // Keyboard (40%)
        double keyScore = kpm switch
        {
            0 => 0, < 10 => 0.2, < 30 => 0.5, < 80 => 0.8, _ => 1.0
        };
        score += keyScore * 0.40;

        // Clicks (20%)
        double clickScore = cpm switch
        {
            0 => 0, < 2 => 0.2, < 5 => 0.4, < 15 => 0.7, _ => 1.0
        };
        score += clickScore * 0.20;

        // Switching (20%, inverted)
        double switchScore = switches switch
        {
            0 => 1.0, < 0.5 => 0.8, < 1 => 0.5, < 2 => 0.3, _ => 0
        };
        score += switchScore * 0.20;

        // Creative app (10%)
        score += (isCreative ? 1.0 : 0.3) * 0.10;

        // Scroll penalty (10%)
        score += (kpm < 5 && spm > 5 ? 0 : 0.5) * 0.10;

        return Math.Min(score, 1.0);
    }

    private static readonly HashSet<string> CreativeApps = new(StringComparer.OrdinalIgnoreCase)
    {
        "Code", "devenv", "idea64", "rider64", "webstorm64", "pycharm64",
        "figma", "Photoshop", "Illustrator",
        "WindowsTerminal", "powershell", "pwsh", "cmd",
        "Notion", "Obsidian", "Linear",
        "FinalCut", "Logic", "Premiere",
    };

    private static bool IsCreativeApp(string? name) =>
        name != null && CreativeApps.Any(c => name.Contains(c, StringComparison.OrdinalIgnoreCase));

    public void ResetWindow()
    {
        _keystrokeCount = 0;
        _clickCount = 0;
        _scrollCount = 0;
        _appSwitchCount = 0;
        _windowSeconds = 0;
        _windowStartTime = null;
    }

    public void ResetAll()
    {
        ResetWindow();
        _extensionCount = 0;
    }
}

// Decision types
public abstract record BreakDecision
{
    public sealed record ShowBreak() : BreakDecision;
    public sealed record Extend(int Minutes, string Reason) : BreakDecision;
}
