using Blink.Core.FlowDetection;

namespace Blink.Core.Compliance;

public sealed record BreakRecord(
    DateTime PromptedAt,
    DateTime? RespondedAt,
    FlowState FlowStateWhenPrompted,
    double FlowScore,
    BreakCompliance Compliance,
    double? BreakDurationSeconds
);
