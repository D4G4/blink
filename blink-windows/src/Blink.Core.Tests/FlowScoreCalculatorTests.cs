using Blink.Core.Abstractions;
using Blink.Core.FlowDetection;

namespace Blink.Core.Tests;

public class FlowScoreCalculatorTests
{
    [Fact]
    public void NoInput_LowishScore()
    {
        var calc = new FlowScoreCalculator();
        var score = calc.CurrentScore(1000);
        Assert.InRange(score, 0.4, 0.65);
    }

    [Fact]
    public void SustainedTyping_HighScore()
    {
        var calc = new FlowScoreCalculator();
        for (int i = 0; i < 60; i++)
            calc.IngestKeystroke(new KeystrokeEvent(940 + i));
        calc.SetCurrentApp("Code"); // creative app

        var score = calc.CurrentScore(1000);
        Assert.True(score > 0.6, $"Sustained typing in IDE should score high, got {score}");
    }

    [Fact]
    public void FrequentAppSwitching_LowScore()
    {
        var calc = new FlowScoreCalculator();
        for (int i = 0; i < 8; i++)
            calc.RecordAppSwitch(new AppSwitchEvent(750 + i * 30, $"app{i}"));

        var score = calc.CurrentScore(1000);
        Assert.True(score < 0.5, $"Heavy switching should reduce score, got {score}");
    }

    [Fact]
    public void HeavyScrolling_BrowsingScore()
    {
        var calc = new FlowScoreCalculator();
        for (int i = 0; i < 30; i++)
            calc.IngestMouseEvent(new MouseEvent(940 + i * 2, new MouseEventKind.Scroll(10)));

        var score = calc.CurrentScore(1000);
        Assert.True(score < 0.55, $"Scrolling without typing = browsing, got {score}");
    }

    [Fact]
    public void CreativeAppBonus()
    {
        var calc1 = new FlowScoreCalculator();
        var calc2 = new FlowScoreCalculator();
        for (int i = 0; i < 30; i++)
        {
            calc1.IngestKeystroke(new KeystrokeEvent(940 + i * 2));
            calc2.IngestKeystroke(new KeystrokeEvent(940 + i * 2));
        }
        calc1.SetCurrentApp("Code");
        calc2.SetCurrentApp("slack");

        Assert.True(calc1.CurrentScore(1000) > calc2.CurrentScore(1000));
    }

    [Fact]
    public void Reset_ClearsState()
    {
        var calc = new FlowScoreCalculator();
        for (int i = 0; i < 20; i++)
            calc.IngestKeystroke(new KeystrokeEvent(980 + i));
        calc.SetCurrentApp("Code");

        var before = calc.CurrentScore(1000);
        calc.Reset();
        var after = calc.CurrentScore(1000);

        Assert.True(after < before);
    }

    [Fact]
    public void ScoreAlways_0_to_1()
    {
        var calc = new FlowScoreCalculator();
        Assert.InRange(calc.CurrentScore(1000), 0, 1);

        for (int i = 0; i < 50; i++)
        {
            calc.IngestKeystroke(new KeystrokeEvent(950 + i));
            calc.IngestMouseEvent(new MouseEvent(950 + i, new MouseEventKind.Click()));
        }
        Assert.InRange(calc.CurrentScore(1000), 0, 1);
    }
}
