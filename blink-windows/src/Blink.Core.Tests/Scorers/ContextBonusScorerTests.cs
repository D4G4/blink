using Blink.Core.FlowDetection.SignalProcessors;

namespace Blink.Core.Tests.Scorers;

public class ContextBonusScorerTests
{
    private readonly ContextBonusScorer _scorer = new();

    [Theory]
    [InlineData("devenv", 1.0)]
    [InlineData("Code", 1.0)]
    [InlineData("WindowsTerminal", 1.0)]
    public void CreativeApp_MaxScore(string name, double expected) =>
        Assert.Equal(expected, _scorer.Score(name));

    [Theory]
    [InlineData("slack", 0.2)]
    [InlineData("OUTLOOK", 0.2)]
    public void ConsumptionApp_LowScore(string name, double expected) =>
        Assert.Equal(expected, _scorer.Score(name));

    [Fact] public void UnknownApp_Neutral() =>
        Assert.Equal(0.5, _scorer.Score("randomapp"));

    [Fact] public void NullApp_Neutral() =>
        Assert.Equal(0.5, _scorer.Score(null));

    [Fact] public void JetBrains_Creative() =>
        Assert.Equal(1.0, _scorer.Score("jetbrains-rider"));
}
