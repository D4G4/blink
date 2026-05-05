using Blink.Core.Timer;

namespace Blink.Core.Tests;

public class AdaptiveTimingEngineTests
{
    [Fact]
    public void NotEnoughData_NoSuggestion()
    {
        var engine = new AdaptiveTimingEngine();
        for (int i = 0; i < 5; i++)
            engine.RecordAcceptedBreak(1200);
        Assert.Null(engine.SuggestedDuration());
    }

    [Fact]
    public void EnoughData_MedianSuggestion()
    {
        var engine = new AdaptiveTimingEngine();
        foreach (var i in new[] { 1200, 1300, 1100, 1400, 1250, 1350, 1150, 1500, 1200, 1300 })
            engine.RecordAcceptedBreak(i);
        var suggested = engine.SuggestedDuration();
        Assert.NotNull(suggested);
        Assert.InRange(suggested.Value, 900, 2700);
    }

    [Fact]
    public void ClampsToMin()
    {
        var engine = new AdaptiveTimingEngine();
        for (int i = 0; i < 15; i++)
            engine.RecordAcceptedBreak(300); // 5 min
        Assert.Equal(900, engine.SuggestedDuration());
    }

    [Fact]
    public void ClampsToMax()
    {
        var engine = new AdaptiveTimingEngine();
        for (int i = 0; i < 15; i++)
            engine.RecordAcceptedBreak(5000); // 83 min
        Assert.Equal(2700, engine.SuggestedDuration());
    }

    [Fact]
    public void LoadSave_Roundtrips()
    {
        var engine = new AdaptiveTimingEngine();
        for (int i = 0; i < 12; i++)
            engine.RecordAcceptedBreak(1200 + i * 10);
        var saved = engine.SavedIntervals();

        var engine2 = new AdaptiveTimingEngine();
        engine2.Load(saved);
        Assert.Equal(engine.SuggestedDuration(), engine2.SuggestedDuration());
    }

    [Fact]
    public void BufferCapsAt50()
    {
        var engine = new AdaptiveTimingEngine();
        for (int i = 0; i < 60; i++)
            engine.RecordAcceptedBreak(1200 + i);
        Assert.Equal(50, engine.SavedIntervals().Length);
    }
}
