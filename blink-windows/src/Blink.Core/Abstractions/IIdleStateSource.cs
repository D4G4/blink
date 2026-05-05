namespace Blink.Core.Abstractions;

public interface IIdleStateSource
{
    double SecondsSinceLastInput();
}
