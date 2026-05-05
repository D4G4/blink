import Foundation

public protocol ContextSource {
    func isMicrophoneActive() -> Bool
    func isCameraActive() -> Bool
    func isInFocusMode() -> Bool
    func isFrontAppFullScreen() -> Bool
    func isMediaPlaying() -> Bool
}
