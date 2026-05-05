namespace Blink.Core.Compliance;

public enum BreakCompliance
{
    Taken,      // user paused for 20+ seconds within 60s of prompt
    Dismissed,  // clicked dismiss within 5s
    Delayed,    // took break but after >60s
    Ignored     // never responded, gave up after 5min
}
