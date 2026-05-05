using Blink.Core.Abstractions;
using Blink.Core.FlowDetection.SignalProcessors;

namespace Blink.Core.FlowDetection;

public sealed class FlowScoreCalculator
{
    private readonly List<double> _keystrokeTimestamps = [];
    private readonly List<MouseEvent> _mouseEvents = [];
    private readonly List<double> _appSwitchTimestamps = [];
    private readonly List<double> _titleChangeTimestamps = [];
    private string? _currentAppId;

    private readonly AppSwitchScorer _appSwitchScorer = new();
    private readonly KeystrokeRhythmScorer _keystrokeRhythmScorer = new();
    private readonly MouseBehaviorScorer _mouseBehaviorScorer = new();
    private readonly WindowStabilityScorer _windowStabilityScorer = new();
    private readonly ContextBonusScorer _contextBonusScorer = new();

    private const double MaxBufferAge = 600; // 10 minutes

    // Weights
    private const double WeightAppSwitch = 0.35;
    private const double WeightKeystroke = 0.25;
    private const double WeightMouse = 0.20;
    private const double WeightWindow = 0.10;
    private const double WeightContext = 0.10;

    public void IngestKeystroke(KeystrokeEvent evt) => _keystrokeTimestamps.Add(evt.Timestamp);
    public void IngestMouseEvent(MouseEvent evt) => _mouseEvents.Add(evt);
    public void RecordAppSwitch(AppSwitchEvent evt)
    {
        _appSwitchTimestamps.Add(evt.Timestamp);
        _currentAppId = evt.AppId;
    }
    public void RecordWindowTitleChange(double timestamp) => _titleChangeTimestamps.Add(timestamp);
    public void SetCurrentApp(string appId) => _currentAppId = appId;

    public double CurrentScore(double now)
    {
        PruneOldEvents(now);

        const double keystrokeWindow = 120;
        var recentKeystrokeCount = _keystrokeTimestamps.Count(t => t > now - keystrokeWindow);

        var appSwitchScore = _appSwitchScorer.Score(_appSwitchTimestamps, now);
        var keystrokeScore = _keystrokeRhythmScorer.Score(_keystrokeTimestamps, now);
        var mouseScore = _mouseBehaviorScorer.Score(_mouseEvents, recentKeystrokeCount, now);
        var windowScore = _windowStabilityScorer.Score(_titleChangeTimestamps, now);
        var contextScore = _contextBonusScorer.Score(_currentAppId);

        return WeightAppSwitch * appSwitchScore
             + WeightKeystroke * keystrokeScore
             + WeightMouse * mouseScore
             + WeightWindow * windowScore
             + WeightContext * contextScore;
    }

    public void Reset()
    {
        _keystrokeTimestamps.Clear();
        _mouseEvents.Clear();
        _appSwitchTimestamps.Clear();
        _titleChangeTimestamps.Clear();
        _currentAppId = null;
    }

    private void PruneOldEvents(double now)
    {
        var cutoff = now - MaxBufferAge;
        _keystrokeTimestamps.RemoveAll(t => t < cutoff);
        _mouseEvents.RemoveAll(e => e.Timestamp < cutoff);
        _appSwitchTimestamps.RemoveAll(t => t < cutoff);
        _titleChangeTimestamps.RemoveAll(t => t < cutoff);
    }
}
