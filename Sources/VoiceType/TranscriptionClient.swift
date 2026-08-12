import Foundation

struct TranscriptionClient {
    static let model = "gpt-4o-mini-transcribe"

    private let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    private let maximumFileSize = 25 * 1_024 * 1_024

    func transcribe(fileURL: URL, apiKey: String, prompt: String) async throws -> String {
        let audio = try Data(contentsOf: fileURL)
        guard audio.count <= maximumFileSize else {
            throw TranscriptionError.recordingTooLarge
        }

        let boundary = "VoiceType-\(UUID().uuidString)"
        var form = MultipartFormData(boundary: boundary)
            .addingField(name: "model", value: Self.model)
            .addingField(name: "response_format", value: "json")
            .addingField(name: "language", value: "en")

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPrompt.isEmpty {
            form = form.addingField(name: "prompt", value: trimmedPrompt)
        }

        let body = form.addingFile(
            name: "file",
            filename: "voice-type.m4a",
            contentType: "audio/mp4",
            data: audio
        )
            .encoded()

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TranscriptionError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            throw TranscriptionError.api(
                envelope?.error.message ?? "OpenAI returned HTTP \(http.statusCode)."
            )
        }

        let result = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return try Self.validatedTranscript(result.text, prompt: trimmedPrompt)
    }

    static func validatedTranscript(_ rawText: String, prompt: String) throws -> String {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw TranscriptionError.emptyTranscript
        }

        let normalizedPrompt = normalizeWhitespace(prompt)
        guard normalizedPrompt.isEmpty || normalizeWhitespace(text) != normalizedPrompt else {
            throw TranscriptionError.emptyTranscript
        }

        return text
    }

    private static func normalizeWhitespace(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

struct MultipartFormData {
    let boundary: String
    private var parts: [Data] = []

    init(boundary: String) {
        self.boundary = boundary
    }

    func addingField(name: String, value: String) -> MultipartFormData {
        var copy = self
        copy.parts.append(Data(
            "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n"
                .utf8
        ))
        return copy
    }

    func addingFile(
        name: String,
        filename: String,
        contentType: String,
        data: Data
    ) -> MultipartFormData {
        var copy = self
        copy.parts.append(Data(
            "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\nContent-Type: \(contentType)\r\n\r\n"
                .utf8
        ))
        copy.parts.append(data)
        copy.parts.append(Data("\r\n".utf8))
        return copy
    }

    func encoded() -> Data {
        var result = Data()
        for part in parts {
            result.append(part)
        }
        result.append(Data("--\(boundary)--\r\n".utf8))
        return result
    }
}

private struct TranscriptionResponse: Decodable {
    let text: String
}

private struct APIErrorEnvelope: Decodable {
    struct APIError: Decodable {
        let message: String
    }

    let error: APIError
}

enum TranscriptionError: LocalizedError, Equatable {
    case invalidResponse
    case recordingTooLarge
    case emptyTranscript
    case api(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "OpenAI returned an invalid response."
        case .recordingTooLarge:
            "That recording is over the 25 MB transcription limit."
        case .emptyTranscript:
            "No speech was detected."
        case let .api(message):
            message
        }
    }
}
