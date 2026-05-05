using Blink.Core.Abstractions;
using Blink.Core.FlowDetection.SignalProcessors;

namespace Blink.Core.Tests.Scorers;

public class MouseBehaviorScorerTests
{
    private readonly MouseBehaviorScorer _scorer = new();

    [Fact] public void NoInput_NeutralScore() =>
        Assert.Equal(0.5, _scorer.Score([], 0, 1000));

    [Fact]
    public void KeyboardOnly_HighScore()
    {
        var score = _scorer.Score([], 50, 1000);
        Assert.True(score > 0.9, $"Keyboard-dominant should be high, got {score}");
    }

    [Fact]
    public void MouseOnly_LowScore()
    {
        var events = Enumerable.Range(0, 20)
            .Select(i => new MouseEvent(940 + i * 3, new MouseEventKind.Click())).ToList();
        var score = _scorer.Score(events, 0, 1000);
        Assert.True(score < 0.2, $"Mouse-only should be low, got {score}");
    }

    [Fact]
    public void HeavyScrolling_Browsing()
    {
        var events = Enumerable.Range(0, 25)
            .Select(i => new MouseEvent(940 + i * 2, new MouseEventKind.Scroll(10))).ToList();
        var score = _scorer.Score(events, 2, 1000);
        Assert.True(score < 0.2, $"Heavy scrolling = browsing, got {score}");
    }
}
