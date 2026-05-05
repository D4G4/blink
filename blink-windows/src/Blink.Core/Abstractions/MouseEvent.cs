namespace Blink.Core.Abstractions;

public readonly record struct MouseEvent(double Timestamp, MouseEventKind Kind);

public abstract record MouseEventKind
{
    public sealed record Move(double DeltaX, double DeltaY) : MouseEventKind;
    public sealed record Scroll(double DeltaY) : MouseEventKind;
    public sealed record Click : MouseEventKind;
}
