import Foundation
import MediaControlBridge
import XCTest

final class MediaControlBridgeTests: XCTestCase {
    func testNowPlayingQueryReturnsWithinItsTimeout() {
        var known = false
        let startedAt = ContinuousClock.now
        _ = VTMediaPlaybackIsPlaying(0.2, &known)
        let elapsed = startedAt.duration(to: .now)

        XCTAssertLessThan(elapsed, .seconds(1))
    }

    func testPauseAndResumeWhenExplicitlyEnabled() throws {
        guard ProcessInfo.processInfo.environment["VOICE_TYPE_TEST_MEDIA_CONTROL"] == "1" else {
            throw XCTSkip("Media control integration test is opt-in")
        }

        var known = false
        guard VTMediaPlaybackIsPlaying(0.2, &known), known else {
            throw XCTSkip("No active Now Playing session")
        }

        let paused = VTMediaPlaybackSendPause()
        if paused {
            addTeardownBlock {
                _ = VTMediaPlaybackSendPlay()
            }
        }
        XCTAssertTrue(paused)

        Thread.sleep(forTimeInterval: 0.25)
        var pausedStateKnown = false
        let stillPlaying = VTMediaPlaybackIsPlaying(0.2, &pausedStateKnown)
        XCTAssertTrue(pausedStateKnown)
        XCTAssertFalse(stillPlaying)
    }
}
