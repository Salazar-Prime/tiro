import Foundation

struct VoiceGestureMachine {
    enum State: Equatable {
        case idle
        case pressing
        case waitingForSecondTap
        case locked
        case stoppingLockedRecording
    }

    private(set) var state: State = .idle
    let doubleTapInterval: TimeInterval

    init(doubleTapInterval: TimeInterval = 0.34) {
        self.doubleTapInterval = doubleTapInterval
    }

    mutating func comboBecameDown() -> [VoiceGestureAction] {
        switch state {
        case .idle:
            state = .pressing
            return [.beginRecording]
        case .waitingForSecondTap:
            state = .locked
            return [.cancelScheduledFinish, .lockRecording]
        case .locked:
            state = .stoppingLockedRecording
            return [.finishRecording]
        case .pressing, .stoppingLockedRecording:
            return []
        }
    }

    mutating func comboBecameUp() -> [VoiceGestureAction] {
        switch state {
        case .pressing:
            state = .waitingForSecondTap
            return [.scheduleFinish(after: doubleTapInterval)]
        case .stoppingLockedRecording:
            state = .idle
            return []
        case .idle, .waitingForSecondTap, .locked:
            return []
        }
    }

    mutating func scheduledFinishFired() -> [VoiceGestureAction] {
        guard state == .waitingForSecondTap else { return [] }
        state = .idle
        return [.finishRecording]
    }

    mutating func reset() {
        state = .idle
    }
}

enum VoiceGestureAction: Equatable {
    case beginRecording
    case cancelRecording
    case scheduleFinish(after: TimeInterval)
    case cancelScheduledFinish
    case lockRecording
    case finishRecording
}
