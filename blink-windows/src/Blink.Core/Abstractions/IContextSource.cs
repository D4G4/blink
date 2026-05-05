namespace Blink.Core.Abstractions;

public interface IContextSource
{
    bool IsMicrophoneActive();
    bool IsCameraActive();
    bool IsInFocusMode();
    bool IsFrontAppFullScreen();
    bool IsMediaPlaying();
}
