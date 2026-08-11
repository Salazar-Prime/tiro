import Foundation
import XCTest
@testable import VoiceType

final class MultipartFormDataTests: XCTestCase {
    func testEncodesFieldsFileAndClosingBoundary() throws {
        let result = MultipartFormData(boundary: "BOUNDARY")
            .addingField(name: "model", value: "gpt-4o-mini-transcribe")
            .addingField(name: "language", value: "en")
            .addingField(name: "prompt", value: "Correct grammar and spelling.")
            .addingFile(
                name: "file",
                filename: "audio.m4a",
                contentType: "audio/mp4",
                data: Data([0x01, 0x02])
            )
            .encoded()

        let prefix = String(decoding: result.dropLast(18), as: UTF8.self)
        XCTAssertTrue(prefix.contains("name=\"model\"\r\n\r\ngpt-4o-mini-transcribe"))
        XCTAssertTrue(prefix.contains("name=\"language\"\r\n\r\nen"))
        XCTAssertTrue(prefix.contains("name=\"prompt\"\r\n\r\nCorrect grammar and spelling."))
        XCTAssertTrue(prefix.contains("filename=\"audio.m4a\""))
        XCTAssertTrue(result.suffix(14).elementsEqual(Data("--BOUNDARY--\r\n".utf8)))
        XCTAssertTrue(result.contains(0x01))
        XCTAssertTrue(result.contains(0x02))
    }
}
