using Blink.Core.FlowDetection.SignalProcessors;

namespace Blink.Core.Tests.Scorers;

public class KeystrokeRhythmScorerTests
{
    private readonly KeystrokeRhythmScorer _scorer = new();

    [Fact] public void NoKeystrokes_ZeroScore() =>
        Assert.Equal(0.0, _scorer.Score([], 1000));

    [Fact] public void TooFewKeystrokes_ZeroScore() =>
        Assert.Equal(0.0, _scorer.Score([998, 999, 1000], 1000));

    [Fact]
    public void SteadyTyping_HighScore()
    {
        var timestamps = Enumerable.Range(0, 60).Select(i => 940.0 + i).ToList();
        var score = _scorer.Score(timestamps, 1000);
        Assert.True(score > 0.5, $"Steady typing should produce decent score, got {score}");
    }

    [Fact]
    public void OldKeystrokesIgnored()
    {
        var timestamps = Enumerable.Range(0, 30).Select(i => 600.0 + i).ToList();
        Assert.Equal(0.0, _scorer.Score(timestamps, 1000));
    }
}
