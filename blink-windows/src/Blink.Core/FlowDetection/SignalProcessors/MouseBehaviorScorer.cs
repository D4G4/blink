using Blink.Core.Abstractions;

namespace Blink.Core.FlowDetection.SignalProcessors;

public sealed class MouseBehaviorScorer
{
    private const double WindowSeconds = 120; // 2 minutes

    public double Score(List<MouseEvent> mouseEvents, int keystrokeCount, double now)
    {
        var windowStart = now - WindowSeconds;
        var recentMouse = mouseEvents.Where(e => e.Timestamp > windowStart).ToList();

        var scrollCount = recentMouse.Count(e => e.Kind is MouseEventKind.Scroll);
        var clickCount = recentMouse.Count(e => e.Kind is MouseEventKind.Click);
        var moveCount = recentMouse.Count(e => e.Kind is MouseEventKind.Move);

        var totalMouse = scrollCount + clickCount + moveCount;
        var totalInput = totalMouse + keystrokeCount;

        if (totalInput == 0) return 0.5; // no input = neutral

        var keyboardRatio = (double)keystrokeCount / totalInput;

        // Heavy scrolling with no typing = reading/browsing
        if (scrollCount > 20 && keystrokeCount < 5) return 0.15;

        // Mouse-only with no keyboard = browsing
        if (keystrokeCount == 0 && totalMouse > 10) return 0.1;

        // High keyboard ratio = deep work
        return Math.Min(1.0, keyboardRatio * 1.2);
    }
}
