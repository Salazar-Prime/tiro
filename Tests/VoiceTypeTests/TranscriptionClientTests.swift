import XCTest
@testable import VoiceType

final class TranscriptionClientTests: XCTestCase {
    func testRejectsEmptyTranscript() {
        XCTAssertThrowsError(
            try TranscriptionClient.validatedTranscript("  \n", prompt: "Correct grammar.")
        ) { error in
            XCTAssertEqual(error as? TranscriptionError, .emptyTranscript)
        }
    }

    func testRejectsTranscriptThatEchoesPrompt() {
        XCTAssertThrowsError(
            try TranscriptionClient.validatedTranscript(
                "Remove filler words.\nCorrect grammar and spelling.",
                prompt: "Remove filler words. Correct grammar and spelling."
            )
        ) { error in
            XCTAssertEqual(error as? TranscriptionError, .emptyTranscript)
        }
    }

    func testAcceptsTranscriptDifferentFromPrompt() throws {
        let transcript = try TranscriptionClient.validatedTranscript(
            "  This is the transcript.\n",
            prompt: "Correct grammar and spelling."
        )

        XCTAssertEqual(transcript, "This is the transcript.")
    }
}
