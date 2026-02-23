import Foundation

public final class SpeakerStreamClient: @unchecked Sendable {
  public enum Error: Swift.Error, LocalizedError, Equatable {
    case invalidURL(String)
    case invalidResponse
    case httpStatus(Int)
    case invalidPcmMetadata(String)

    public var errorDescription: String? {
      switch self {
      case .invalidURL(let value):
        return "Invalid URL: \(value)"
      case .invalidResponse:
        return "Speaker stream response was not HTTP."
      case .httpStatus(let code):
        return "Speaker stream unavailable (HTTP \(code))."
      case .invalidPcmMetadata(let detail):
        return "Invalid speaker PCM metadata: \(detail)"
      }
    }
  }

  private let session: URLSession

  public init(session: URLSession = .shared) {
    self.session = session
  }

  @discardableResult
  public func open(
    baseURL: String,
    maxBytes: Int = 32_768,
    chunkSize: Int = 1024,
    onChunk: @escaping @Sendable (Data) -> Void = { _ in }
  ) async throws -> SpeakerPcmMetadata {
    let normalized = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
    guard let url = URL(string: normalized + "/api/speaker/stream") else {
      throw Error.invalidURL(baseURL)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.timeoutInterval = 20
    request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")

    let (bytes, response) = try await session.bytes(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw Error.invalidResponse
    }
    guard (200...299).contains(http.statusCode) else {
      throw Error.httpStatus(http.statusCode)
    }

    let metadata = try parseMetadata(http)
    var totalBytes = 0
    var buffer: [UInt8] = []
    buffer.reserveCapacity(chunkSize)

    for try await byte in bytes {
      buffer.append(byte)
      if buffer.count >= chunkSize {
        let chunk = Data(buffer)
        onChunk(chunk)
        totalBytes += chunk.count
        buffer.removeAll(keepingCapacity: true)
      }
      if maxBytes > 0 && totalBytes >= maxBytes {
        break
      }
    }

    if !buffer.isEmpty && (maxBytes <= 0 || totalBytes < maxBytes) {
      let finalChunk = Data(buffer)
      onChunk(finalChunk)
    }

    return metadata
  }

  private func parseMetadata(_ response: HTTPURLResponse) throws -> SpeakerPcmMetadata {
    let encoding = (response.value(forHTTPHeaderField: "X-PCM-ENCODING") ?? "s16le")
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    guard encoding == "s16le" else {
      throw Error.invalidPcmMetadata("unsupported encoding \(encoding)")
    }

    let sampleRateRaw = response.value(forHTTPHeaderField: "X-PCM-SAMPLE-RATE") ?? "48000"
    let channelsRaw = response.value(forHTTPHeaderField: "X-PCM-CHANNELS") ?? "1"

    guard let sampleRate = Int(sampleRateRaw), (8000...96000).contains(sampleRate) else {
      throw Error.invalidPcmMetadata("invalid sample rate \(sampleRateRaw)")
    }
    guard let channels = Int(channelsRaw), (1...2).contains(channels) else {
      throw Error.invalidPcmMetadata("invalid channels \(channelsRaw)")
    }

    return SpeakerPcmMetadata(encoding: encoding, sampleRate: sampleRate, channels: channels)
  }
}
