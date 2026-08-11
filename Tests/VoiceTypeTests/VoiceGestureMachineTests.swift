import XCTest
@testable import VoiceType

final class VoiceGestureMachineTests: XCTestCase {
    func testHoldToTalkFinishesAfterDoubleTapWindow() {
        var machine = VoiceGestureMachine(doubleTapInterval: 0.34)

        XCTAssertEqual(machine.comboBecameDown(), [.beginRecording])
        XCTAssertEqual(machine.comboBecameUp(), [.scheduleFinish(after: 0.34)])
        XCTAssertEqual(machine.state, .waitingForSecondTap)
        XCTAssertEqual(machine.scheduledFinishFired(), [.finishRecording])
        XCTAssertEqual(machine.state, .idle)
    }

    func testDoubleTapLocksUntilNextPress() {
        var machine = VoiceGestureMachine()

        XCTAssertEqual(machine.comboBecameDown(), [.beginRecording])
        _ = machine.comboBecameUp()
        XCTAssertEqual(
            machine.comboBecameDown(),
            [.cancelScheduledFinish, .lockRecording]
        )
        XCTAssertEqual(machine.state, .locked)
        XCTAssertEqual(machine.comboBecameUp(), [])
        XCTAssertEqual(machine.comboBecameDown(), [.finishRecording])
        XCTAssertEqual(machine.state, .stoppingLockedRecording)
        XCTAssertEqual(machine.comboBecameUp(), [])
        XCTAssertEqual(machine.state, .idle)
    }

    func testScheduledCallbackDoesNothingAfterLock() {
        var machine = VoiceGestureMachine()
        _ = machine.comboBecameDown()
        _ = machine.comboBecameUp()
        _ = machine.comboBecameDown()

        XCTAssertEqual(machine.scheduledFinishFired(), [])
        XCTAssertEqual(machine.state, .locked)
    }
}
