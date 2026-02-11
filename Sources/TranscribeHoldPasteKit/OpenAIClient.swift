import Foundation

public struct OpenAIClient: Sendable {
    public enum ClientError: Error {
        case invalidResponse
        case httpError(statusCode: Int, body: String?)
        case decodeError
    }

    public let apiKey: String
    public let baseURL: URL

    public init(apiKey: String, baseURL: URL = URL(string: "https://api.openai.com")!) {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }

    public func transcribe(fileURL: URL, model: String, language: String? = nil) async throws -> String {
        let url = baseURL.appendingPathComponent("v1/audio/transcriptions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body = try MultipartFormData(boundary: boundary)
            .addText(name: "model", value: model)
            .addOptionalText(name: "language", value: language)
            .addFile(name: "file", fileURL: fileURL, filename: fileURL.lastPathComponent, mimeType: "audio/m4a")
            .finalize()

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }

        if !(200...299).contains(http.statusCode) {
            let bodyText = String(data: data, encoding: .utf8)
            throw ClientError.httpError(statusCode: http.statusCode, body: bodyText)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClientError.decodeError
        }
        if let text = json["text"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        throw ClientError.decodeError
    }

    public func promptTransform(text: String, prompt: String, model: String) async throws -> String {
        let url = baseURL.appendingPathComponent("v1/responses")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "input": [
                ["role": "system", "content": prompt],
                ["role": "user", "content": text],
            ],
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }

        if !(200...299).contains(http.statusCode) {
            let bodyText = String(data: data, encoding: .utf8)
            throw ClientError.httpError(statusCode: http.statusCode, body: bodyText)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClientError.decodeError
        }

        if let outputText = OpenAIResponseTextExtractor.extract(from: json), !outputText.isEmpty {
            return outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        throw ClientError.decodeError
    }
}

private enum OpenAIResponseTextExtractor {
    static func extract(from json: [String: Any]) -> String? {
        guard let output = json["output"] as? [[String: Any]] else { return nil }
        var parts: [String] = []
        for item in output {
            guard let content = item["content"] as? [[String: Any]] else { continue }
            for c in content {
                if let type = c["type"] as? String, type == "output_text" {
                    if let text = c["text"] as? String {
                        parts.append(text)
                    }
                } else if let text = c["text"] as? String {
                    parts.append(text)
                }
            }
        }
        if parts.isEmpty { return nil }
        return parts.joined(separator: "\n")
    }
}

private struct MultipartFormData {
    private var data = Data()
    private let boundary: String

    init(boundary: String) {
        self.boundary = boundary
    }

    func addText(name: String, value: String) -> MultipartFormData {
        var copy = self
        copy.appendLine("--\(boundary)")
        copy.appendLine("Content-Disposition: form-data; name=\"\(name)\"")
        copy.appendLine("")
        copy.appendLine(value)
        return copy
    }

    func addOptionalText(name: String, value: String?) -> MultipartFormData {
        guard let value, !value.isEmpty else { return self }
        return addText(name: name, value: value)
    }

    func addFile(name: String, fileURL: URL, filename: String, mimeType: String) throws -> MultipartFormData {
        var copy = self
        let fileData = try Data(contentsOf: fileURL)

        copy.appendLine("--\(boundary)")
        copy.appendLine("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"")
        copy.appendLine("Content-Type: \(mimeType)")
        copy.appendLine("")
        copy.data.append(fileData)
        copy.appendLine("")

        return copy
    }

    func finalize() -> Data {
        var copy = self
        copy.appendLine("--\(boundary)--")
        return copy.data
    }

    private mutating func appendLine(_ line: String) {
        data.append(contentsOf: Array((line + "\r\n").utf8))
    }
}
