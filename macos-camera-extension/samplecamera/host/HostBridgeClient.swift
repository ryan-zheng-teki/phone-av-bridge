import Foundation
import AppKit

final class HostBridgeClient {
    struct HostStatusSnapshot {
        let paired: Bool
        let hostStatus: String
        let phoneName: String?
        let phoneId: String?
        let camera: Bool
        let microphone: Bool
        let speaker: Bool
        let cameraLens: String
        let cameraOrientationMode: String
        let cameraAvailable: Bool
        let microphoneAvailable: Bool
        let speakerAvailable: Bool
        let cameraStreamUrl: String?
        let issues: [String]
    }

    struct QrTokenSnapshot {
        let token: String
        let expiresAtRaw: String?
        let payloadText: String?
        let qrImageDataUrl: String?
    }

    enum ClientError: LocalizedError {
        case invalidPayload
        case requestFailed(statusCode: Int)

        var errorDescription: String? {
            switch self {
            case .invalidPayload:
                return "host response payload malformed"
            case .requestFailed(let statusCode):
                return "host request failed (HTTP \(statusCode))"
            }
        }
    }

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func health(timeout: TimeInterval = 1.2, completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: baseURL.appendingPathComponent("health"))
        request.timeoutInterval = timeout
        session.dataTask(with: request) { _, response, error in
            guard error == nil,
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                completion(false)
                return
            }
            completion(true)
        }.resume()
    }

    func fetchStatus(timeout: TimeInterval = 1.5, completion: @escaping (Result<HostStatusSnapshot, Error>) -> Void) {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/status"))
        request.timeoutInterval = timeout
        session.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                completion(.failure(ClientError.requestFailed(statusCode: http.statusCode)))
                return
            }
            guard let data else {
                completion(.failure(ClientError.invalidPayload))
                return
            }
            do {
                let payload = try Self.parseHostStatus(data: data)
                completion(.success(payload))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func issueQrToken(timeout: TimeInterval = 2.0, completion: @escaping (Result<QrTokenSnapshot, Error>) -> Void) {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/bootstrap/qr-token"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        session.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                completion(.failure(ClientError.requestFailed(statusCode: http.statusCode)))
                return
            }
            guard let data else {
                completion(.failure(ClientError.invalidPayload))
                return
            }
            do {
                let payload = try Self.parseQrToken(data: data)
                completion(.success(payload))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private static func parseHostStatus(data: Data) throws -> HostStatusSnapshot {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let status = root["status"] as? [String: Any]
        else {
            throw ClientError.invalidPayload
        }

        let paired = status["paired"] as? Bool ?? false
        let hostStatus = status["hostStatus"] as? String ?? (paired ? "Paired" : "Not Paired")
        let phone = status["phone"] as? [String: Any]
        let resources = status["resources"] as? [String: Any]
        let capabilities = status["capabilities"] as? [String: Any]
        let phoneCamera = status["phoneCamera"] as? [String: Any]
        let issues = (status["issues"] as? [[String: Any]] ?? []).compactMap { issue in
            let resource = issue["resource"] as? String ?? "resource"
            let message = issue["message"] as? String ?? "unknown issue"
            return "\(resource): \(message)"
        }

        return HostStatusSnapshot(
            paired: paired,
            hostStatus: hostStatus,
            phoneName: phone?["deviceName"] as? String,
            phoneId: phone?["deviceId"] as? String,
            camera: resources?["camera"] as? Bool ?? false,
            microphone: resources?["microphone"] as? Bool ?? false,
            speaker: resources?["speaker"] as? Bool ?? false,
            cameraLens: ((phoneCamera?["lens"] as? String) ?? "back").trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            cameraOrientationMode: ((phoneCamera?["orientationMode"] as? String) ?? "auto").trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            cameraAvailable: capabilities?["camera"] as? Bool ?? true,
            microphoneAvailable: capabilities?["microphone"] as? Bool ?? true,
            speakerAvailable: capabilities?["speaker"] as? Bool ?? true,
            cameraStreamUrl: (status["cameraStreamUrl"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            issues: issues
        )
    }

    private static func parseQrToken(data: Data) throws -> QrTokenSnapshot {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let qrToken = root["qrToken"] as? [String: Any]
        else {
            throw ClientError.invalidPayload
        }
        return QrTokenSnapshot(
            token: (qrToken["token"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            expiresAtRaw: (qrToken["expiresAt"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            payloadText: (qrToken["payloadText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            qrImageDataUrl: qrToken["qrImageDataUrl"] as? String
        )
    }
}
