using Blink.Core.FlowDetection.SignalProcessors;

namespace Blink.Core.Tests.Scorers;

public class AppSwitchScorerTests
{
    private readonly AppSwitchScorer _scorer = new();

    [Fact] public void NoSwitches_MaxScore() =>
        Assert.Equal(1.0, _scorer.Score([], 1000));

    [Fact] public void OneSwitch_HighScore() =>
        Assert.Equal(0.85, _scorer.Score([999], 1000));

    [Fact] public void FivePlusSwitches_ZeroScore() =>
        Assert.Equal(0.0, _scorer.Score(Enumerable.Range(0, 6).Select(i => 900.0 + i * 10).ToList(), 1000));

    [Fact] public void OldSwitchesIgnored()
    {
        var timestamps = Enumerable.Range(0, 10).Select(i => 300.0 + i * 10).ToList();
        Assert.Equal(1.0, _scorer.Score(timestamps, 1000));
    }
}
