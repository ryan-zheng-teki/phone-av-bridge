import Cocoa

struct CameraMainViewRefs {
    let statusBadge: NSTextField
    let statusDetailLabel: NSTextField
    let streamDemandLabel: NSTextField
    let hostBridgeBadge: NSTextField
    let hostBridgeDetailLabel: NSTextField
    let hostBridgeStartButton: NSButton
    let hostBridgeOpenButton: NSButton
    let qrStatusLabel: NSTextField
    let qrExpiryLabel: NSTextField
    let qrImageView: NSImageView
    let qrRegenerateButton: NSButton
    let qrCopyPayloadButton: NSButton
    let resourceStatusBadge: NSTextField
    let phoneIdentityLabel: NSTextField
    let resourceIssuesLabel: NSTextField
    let cameraStatusChip: NSTextField
    let microphoneStatusChip: NSTextField
    let speakerStatusChip: NSTextField
    let cameraLensValueLabel: NSTextField
    let cameraOrientationValueLabel: NSTextField
    let syncResourceButton: NSButton
    let logTextView: NSTextView
}

final class CameraMainViewBuilder {
    func build(in view: NSView, target: AnyObject) -> CameraMainViewRefs {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.spacing = 14
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            rootStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
        ])

        let titleLabel = NSTextField(labelWithString: "Phone AV Bridge Camera")
        titleLabel.font = NSFont.systemFont(ofSize: 30, weight: .bold)
        titleLabel.textColor = .labelColor

        let subtitleLabel = NSTextField(labelWithString: "Runs your virtual camera extension and receives live frames from host bridge.")
        subtitleLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.maximumNumberOfLines = 2

        rootStack.addArrangedSubview(titleLabel)
        rootStack.addArrangedSubview(subtitleLabel)

        let hostCard = NSBox()
        hostCard.boxType = .custom
        hostCard.cornerRadius = 12
        hostCard.fillColor = NSColor.controlBackgroundColor
        hostCard.borderColor = NSColor.separatorColor
        hostCard.borderWidth = 1
        hostCard.translatesAutoresizingMaskIntoConstraints = false
        rootStack.addArrangedSubview(hostCard)

        let hostStack = NSStackView()
        hostStack.orientation = .vertical
        hostStack.spacing = 8
        hostStack.translatesAutoresizingMaskIntoConstraints = false
        hostCard.contentView?.addSubview(hostStack)
        NSLayoutConstraint.activate([
            hostStack.topAnchor.constraint(equalTo: hostCard.contentView!.topAnchor, constant: 12),
            hostStack.leadingAnchor.constraint(equalTo: hostCard.contentView!.leadingAnchor, constant: 12),
            hostStack.trailingAnchor.constraint(equalTo: hostCard.contentView!.trailingAnchor, constant: -12),
            hostStack.bottomAnchor.constraint(equalTo: hostCard.contentView!.bottomAnchor, constant: -12),
        ])

        let hostBridgeBadge = NSTextField(labelWithString: "Offline")
        hostBridgeBadge.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        hostBridgeBadge.alignment = .center
        hostBridgeBadge.wantsLayer = true
        hostBridgeBadge.layer?.cornerRadius = 8
        hostBridgeBadge.layer?.masksToBounds = true
        hostBridgeBadge.backgroundColor = .clear
        hostBridgeBadge.drawsBackground = true

        let hostBridgeDetailLabel = NSTextField(labelWithString: "Checking host bridge service status...")
        hostBridgeDetailLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        hostBridgeDetailLabel.textColor = .secondaryLabelColor
        hostBridgeDetailLabel.lineBreakMode = .byWordWrapping
        hostBridgeDetailLabel.maximumNumberOfLines = 2

        let hostControlsRow = NSStackView()
        hostControlsRow.orientation = .horizontal
        hostControlsRow.distribution = .fillProportionally
        hostControlsRow.spacing = 10

        let hostBridgeStartButton = NSButton(title: "Start Host Bridge", target: target, action: Selector(("startHostBridge:")))
        hostBridgeStartButton.bezelStyle = .rounded
        hostBridgeStartButton.controlSize = .large

        let hostBridgeOpenButton = NSButton(title: "Open Host UI", target: target, action: Selector(("openHostBridgeUI:")))
        hostBridgeOpenButton.bezelStyle = .texturedRounded
        hostBridgeOpenButton.controlSize = .large

        hostControlsRow.addArrangedSubview(hostBridgeStartButton)
        hostControlsRow.addArrangedSubview(hostBridgeOpenButton)

        hostStack.addArrangedSubview(hostBridgeBadge)
        hostStack.addArrangedSubview(hostBridgeDetailLabel)
        hostStack.addArrangedSubview(hostControlsRow)

        let qrContainer = NSStackView()
        qrContainer.orientation = .horizontal
        qrContainer.alignment = .top
        qrContainer.spacing = 12

        let qrImageView = NSImageView()
        qrImageView.wantsLayer = true
        qrImageView.layer?.borderWidth = 1
        qrImageView.layer?.borderColor = NSColor.separatorColor.cgColor
        qrImageView.layer?.cornerRadius = 10
        qrImageView.imageScaling = .scaleProportionallyUpOrDown
        qrImageView.imageAlignment = .alignCenter
        qrImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            qrImageView.widthAnchor.constraint(equalToConstant: 172),
            qrImageView.heightAnchor.constraint(equalToConstant: 172),
        ])

        let qrInfoStack = NSStackView()
        qrInfoStack.orientation = .vertical
        qrInfoStack.spacing = 4

        let qrTitleLabel = NSTextField(labelWithString: "Phone Pairing QR")
        qrTitleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        qrTitleLabel.textColor = .labelColor

        let qrStatusLabel = NSTextField(labelWithString: "Checking host bridge...")
        qrStatusLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        qrStatusLabel.textColor = .secondaryLabelColor
        qrStatusLabel.lineBreakMode = .byWordWrapping
        qrStatusLabel.maximumNumberOfLines = 2

        let qrExpiryLabel = NSTextField(labelWithString: "Expiry: unknown")
        qrExpiryLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        qrExpiryLabel.textColor = .secondaryLabelColor

        let qrButtonsRow = NSStackView()
        qrButtonsRow.orientation = .horizontal
        qrButtonsRow.spacing = 8

        let qrRegenerateButton = NSButton(title: "Regenerate QR", target: target, action: Selector(("regenerateQrToken:")))
        qrRegenerateButton.bezelStyle = .rounded
        qrRegenerateButton.controlSize = .regular

        let qrCopyPayloadButton = NSButton(title: "Copy Payload", target: target, action: Selector(("copyQrPayload:")))
        qrCopyPayloadButton.bezelStyle = .texturedRounded
        qrCopyPayloadButton.controlSize = .regular

        qrButtonsRow.addArrangedSubview(qrRegenerateButton)
        qrButtonsRow.addArrangedSubview(qrCopyPayloadButton)

        qrInfoStack.addArrangedSubview(qrTitleLabel)
        qrInfoStack.addArrangedSubview(qrStatusLabel)
        qrInfoStack.addArrangedSubview(qrExpiryLabel)
        qrInfoStack.addArrangedSubview(qrButtonsRow)

        qrContainer.addArrangedSubview(qrImageView)
        qrContainer.addArrangedSubview(qrInfoStack)
        hostStack.addArrangedSubview(qrContainer)

        let divider = NSBox()
        divider.boxType = .separator
        hostStack.addArrangedSubview(divider)

        let resourceStatusBadge = NSTextField(labelWithString: "Unavailable")
        resourceStatusBadge.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        resourceStatusBadge.alignment = .center
        resourceStatusBadge.wantsLayer = true
        resourceStatusBadge.layer?.cornerRadius = 8
        resourceStatusBadge.layer?.masksToBounds = true
        resourceStatusBadge.backgroundColor = .clear
        resourceStatusBadge.drawsBackground = true

        let phoneIdentityLabel = NSTextField(labelWithString: "Phone: unknown")
        phoneIdentityLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        phoneIdentityLabel.textColor = .secondaryLabelColor
        phoneIdentityLabel.lineBreakMode = .byTruncatingMiddle

        let resourceIssuesLabel = NSTextField(labelWithString: "Issues: n/a")
        resourceIssuesLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        resourceIssuesLabel.textColor = .secondaryLabelColor
        resourceIssuesLabel.lineBreakMode = .byWordWrapping
        resourceIssuesLabel.maximumNumberOfLines = 2

        let (cameraRow, cameraStatusChip) = Self.makeResourceRow("Camera")
        let (microphoneRow, microphoneStatusChip) = Self.makeResourceRow("Microphone")
        let (speakerRow, speakerStatusChip) = Self.makeResourceRow("Speaker")

        let (lensRow, cameraLensValueLabel) = Self.makeMetadataRow("Camera Lens", initialValue: "Unknown")
        let (orientationRow, cameraOrientationValueLabel) = Self.makeMetadataRow("Orientation", initialValue: "Unknown")

        let resourceControlsRow = NSStackView()
        resourceControlsRow.orientation = .horizontal
        resourceControlsRow.distribution = .fillProportionally
        resourceControlsRow.spacing = 10
        let syncResourceButton = NSButton(title: "Refresh Status", target: target, action: Selector(("syncHostResourceStatus:")))
        syncResourceButton.bezelStyle = .texturedRounded
        syncResourceButton.controlSize = .large
        resourceControlsRow.addArrangedSubview(syncResourceButton)

        hostStack.addArrangedSubview(resourceStatusBadge)
        hostStack.addArrangedSubview(phoneIdentityLabel)
        hostStack.addArrangedSubview(resourceIssuesLabel)
        hostStack.addArrangedSubview(cameraRow)
        hostStack.addArrangedSubview(microphoneRow)
        hostStack.addArrangedSubview(speakerRow)
        hostStack.addArrangedSubview(lensRow)
        hostStack.addArrangedSubview(orientationRow)
        hostStack.addArrangedSubview(resourceControlsRow)

        let statusCard = NSBox()
        statusCard.boxType = .custom
        statusCard.cornerRadius = 12
        statusCard.fillColor = NSColor.controlBackgroundColor
        statusCard.borderColor = NSColor.separatorColor
        statusCard.borderWidth = 1
        statusCard.translatesAutoresizingMaskIntoConstraints = false
        rootStack.addArrangedSubview(statusCard)

        let statusStack = NSStackView()
        statusStack.orientation = .vertical
        statusStack.spacing = 8
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusCard.contentView?.addSubview(statusStack)
        NSLayoutConstraint.activate([
            statusStack.topAnchor.constraint(equalTo: statusCard.contentView!.topAnchor, constant: 12),
            statusStack.leadingAnchor.constraint(equalTo: statusCard.contentView!.leadingAnchor, constant: 12),
            statusStack.trailingAnchor.constraint(equalTo: statusCard.contentView!.trailingAnchor, constant: -12),
            statusStack.bottomAnchor.constraint(equalTo: statusCard.contentView!.bottomAnchor, constant: -12),
        ])

        let statusBadge = NSTextField(labelWithString: "Idle")
        statusBadge.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        statusBadge.alignment = .center
        statusBadge.wantsLayer = true
        statusBadge.layer?.cornerRadius = 8
        statusBadge.layer?.masksToBounds = true
        statusBadge.backgroundColor = NSColor.clear
        statusBadge.drawsBackground = true

        let statusDetailLabel = NSTextField(labelWithString: "Preparing frame server and extension environment…")
        statusDetailLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        statusDetailLabel.textColor = .secondaryLabelColor
        statusDetailLabel.lineBreakMode = .byWordWrapping
        statusDetailLabel.maximumNumberOfLines = 2

        let streamDemandLabel = NSTextField(labelWithString: "Capture demand: unknown")
        streamDemandLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        streamDemandLabel.textColor = .secondaryLabelColor

        let controlsRow = NSStackView()
        controlsRow.orientation = .horizontal
        controlsRow.distribution = .fillProportionally
        controlsRow.spacing = 10

        let enableButton = NSButton(title: "Enable Extension", target: target, action: Selector(("activate:")))
        enableButton.bezelStyle = .rounded
        enableButton.controlSize = .large

        let disableButton = NSButton(title: "Disable Extension", target: target, action: Selector(("deactivate:")))
        disableButton.bezelStyle = .rounded
        disableButton.controlSize = .large

        let settingsButton = NSButton(title: "Open Settings", target: target, action: Selector(("openExtensionsSettings:")))
        settingsButton.bezelStyle = .texturedRounded
        settingsButton.controlSize = .large

        controlsRow.addArrangedSubview(enableButton)
        controlsRow.addArrangedSubview(disableButton)
        controlsRow.addArrangedSubview(settingsButton)

        statusStack.addArrangedSubview(statusBadge)
        statusStack.addArrangedSubview(statusDetailLabel)
        statusStack.addArrangedSubview(streamDemandLabel)
        statusStack.addArrangedSubview(controlsRow)

        let logsHeader = NSStackView()
        logsHeader.orientation = .horizontal
        logsHeader.alignment = .centerY
        logsHeader.distribution = .equalSpacing

        let logsTitle = NSTextField(labelWithString: "Runtime Log")
        logsTitle.font = NSFont.systemFont(ofSize: 15, weight: .semibold)

        let clearButton = NSButton(title: "Clear", target: target, action: Selector(("clearLog:")))
        clearButton.bezelStyle = .rounded

        logsHeader.addArrangedSubview(logsTitle)
        logsHeader.addArrangedSubview(clearButton)
        rootStack.addArrangedSubview(logsHeader)

        let logScroll = NSScrollView()
        logScroll.hasVerticalScroller = true
        logScroll.autohidesScrollers = true
        logScroll.borderType = .bezelBorder
        logScroll.translatesAutoresizingMaskIntoConstraints = false
        rootStack.addArrangedSubview(logScroll)
        NSLayoutConstraint.activate([
            logScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 280),
        ])

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.string = "Phone AV Bridge Camera initialized.\n"
        logScroll.documentView = textView

        return CameraMainViewRefs(
            statusBadge: statusBadge,
            statusDetailLabel: statusDetailLabel,
            streamDemandLabel: streamDemandLabel,
            hostBridgeBadge: hostBridgeBadge,
            hostBridgeDetailLabel: hostBridgeDetailLabel,
            hostBridgeStartButton: hostBridgeStartButton,
            hostBridgeOpenButton: hostBridgeOpenButton,
            qrStatusLabel: qrStatusLabel,
            qrExpiryLabel: qrExpiryLabel,
            qrImageView: qrImageView,
            qrRegenerateButton: qrRegenerateButton,
            qrCopyPayloadButton: qrCopyPayloadButton,
            resourceStatusBadge: resourceStatusBadge,
            phoneIdentityLabel: phoneIdentityLabel,
            resourceIssuesLabel: resourceIssuesLabel,
            cameraStatusChip: cameraStatusChip,
            microphoneStatusChip: microphoneStatusChip,
            speakerStatusChip: speakerStatusChip,
            cameraLensValueLabel: cameraLensValueLabel,
            cameraOrientationValueLabel: cameraOrientationValueLabel,
            syncResourceButton: syncResourceButton,
            logTextView: textView
        )
    }

    private static func makeResourceRow(_ name: String) -> (NSStackView, NSTextField) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .equalSpacing

        let label = NSTextField(labelWithString: name)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor

        let chip = NSTextField(labelWithString: "  Off  ")
        chip.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        chip.alignment = .center
        chip.wantsLayer = true
        chip.layer?.cornerRadius = 8
        chip.layer?.masksToBounds = true
        chip.backgroundColor = .clear
        chip.drawsBackground = true
        chip.textColor = .white
        chip.layer?.backgroundColor = NSColor.systemGray.cgColor

        row.addArrangedSubview(label)
        row.addArrangedSubview(chip)
        return (row, chip)
    }

    private static func makeMetadataRow(_ name: String, initialValue: String) -> (NSStackView, NSTextField) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .equalSpacing

        let label = NSTextField(labelWithString: name)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor

        let value = NSTextField(labelWithString: initialValue)
        value.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        value.textColor = .secondaryLabelColor

        row.addArrangedSubview(label)
        row.addArrangedSubview(value)
        return (row, value)
    }
}
