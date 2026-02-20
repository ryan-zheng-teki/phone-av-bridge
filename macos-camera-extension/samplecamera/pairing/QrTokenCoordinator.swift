import Foundation

final class QrTokenCoordinator {
    var onSnapshot: ((HostBridgeClient.QrTokenSnapshot, Bool) -> Void)?
    var onExpiryTick: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onLog: ((String) -> Void)?

    private let hostBridgeClient: HostBridgeClient
    private let isHostOnline: () -> Bool
    private var latestSnapshot: HostBridgeClient.QrTokenSnapshot?
    private var latestExpiryDate: Date?
    private var requestInFlight = false
    private var expiryTimer: Timer?
    private var autoRefreshTimer: Timer?

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601FallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    init(hostBridgeClient: HostBridgeClient, isHostOnline: @escaping () -> Bool) {
        self.hostBridgeClient = hostBridgeClient
        self.isHostOnline = isHostOnline
    }

    deinit {
        stop(reason: "deinit")
    }

    var latestPayloadText: String? {
        latestSnapshot?.payloadText
    }

    func start() {
        guard isHostOnline() else { return }
        if latestSnapshot == nil {
            refresh(manual: false)
        } else {
            refreshExpiryTick()
        }
    }

    func stop(reason: String) {
        clearTimers()
        latestSnapshot = nil
        latestExpiryDate = nil
        requestInFlight = false
        onLog?("qr coordinator stopped reason=\(reason)")
    }

    func refresh(manual: Bool) {
        guard isHostOnline() else {
            onError?("Host bridge offline. Start host bridge to generate QR.")
            return
        }
        if requestInFlight {
            return
        }
        requestInFlight = true
        hostBridgeClient.issueQrToken { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.requestInFlight = false
                switch result {
                case .success(let qrToken):
                    self.latestSnapshot = qrToken
                    self.latestExpiryDate = self.parseExpiryDate(qrToken.expiresAtRaw)
                    self.onSnapshot?(qrToken, manual)
                    self.refreshExpiryTick()
                    self.startExpiryTimer()
                    self.scheduleAutoRefresh()
                    let tokenPreview = qrToken.token.isEmpty ? "n/a" : "\(qrToken.token.prefix(6))…"
                    let expiryText = qrToken.expiresAtRaw ?? "unknown"
                    self.onLog?("qr token ready token=\(tokenPreview) expires=\(expiryText)")
                case .failure(let error):
                    self.onError?("Failed to generate QR token. \(error.localizedDescription)")
                }
            }
        }
    }

    private func clearTimers() {
        expiryTimer?.invalidate()
        expiryTimer = nil
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }

    private func parseExpiryDate(_ rawValue: String?) -> Date? {
        guard let raw = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if let parsed = Self.iso8601Formatter.date(from: raw) {
            return parsed
        }
        return Self.iso8601FallbackFormatter.date(from: raw)
    }

    private func formatRemaining(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        let minutes = total / 60
        let seconds = total % 60
        return "\(minutes)m \(seconds)s"
    }

    @objc private func refreshExpiryTick() {
        guard let expiryDate = latestExpiryDate else {
            onExpiryTick?("Expiry: unknown")
            return
        }

        let remaining = expiryDate.timeIntervalSinceNow
        if remaining <= 0 {
            onExpiryTick?("Expiry: expired (refreshing)")
            if isHostOnline(), !requestInFlight {
                refresh(manual: false)
            }
            return
        }

        onExpiryTick?("Expiry: in \(formatRemaining(remaining))")
    }

    private func startExpiryTimer() {
        expiryTimer?.invalidate()
        expiryTimer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(refreshExpiryTick),
            userInfo: nil,
            repeats: true
        )
    }

    private func scheduleAutoRefresh() {
        autoRefreshTimer?.invalidate()
        guard let expiryDate = latestExpiryDate else { return }
        let refreshInterval = max(1.0, expiryDate.timeIntervalSinceNow - 5.0)
        autoRefreshTimer = Timer.scheduledTimer(
            timeInterval: refreshInterval,
            target: self,
            selector: #selector(handleAutoRefreshTimer),
            userInfo: nil,
            repeats: false
        )
    }

    @objc private func handleAutoRefreshTimer() {
        refresh(manual: false)
    }
}
