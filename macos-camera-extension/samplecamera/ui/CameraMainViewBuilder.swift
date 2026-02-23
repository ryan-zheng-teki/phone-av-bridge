import Cocoa

struct CameraMainViewRefs {
    let wizardTabView: NSTabView
    let wizardBackButton: NSButton
    let wizardNextButton: NSButton
    let stepOneChip: NSTextField
    let stepTwoChip: NSTextField
    let stepThreeChip: NSTextField
    let extensionSetupHintLabel: NSTextField
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
        rootStack.alignment = .centerX
        rootStack.spacing = 12
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            rootStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
        ])

        let titleLabel = NSTextField(labelWithString: "Phone AV Bridge Camera")
        titleLabel.font = NSFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.alignment = .center

        let subtitleLabel = NSTextField(labelWithString: "Guided setup: enable extension first, then connect phone.")
        subtitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.alignment = .center
        subtitleLabel.textColor = .secondaryLabelColor

        rootStack.addArrangedSubview(titleLabel)
        rootStack.addArrangedSubview(subtitleLabel)

        let stepProgressRow = NSStackView()
        stepProgressRow.orientation = .horizontal
        stepProgressRow.alignment = .centerY
        stepProgressRow.distribution = .fillEqually
        stepProgressRow.spacing = 8

        let stepOneChip = Self.makeStepChip("1. Extension")
        let stepTwoChip = Self.makeStepChip("2. Connect Phone")
        let stepThreeChip = Self.makeStepChip("3. Runtime")

        stepProgressRow.addArrangedSubview(stepOneChip)
        stepProgressRow.addArrangedSubview(stepTwoChip)
        stepProgressRow.addArrangedSubview(stepThreeChip)
        rootStack.addArrangedSubview(stepProgressRow)

        let wizardCard = Self.makeCard()
        rootStack.addArrangedSubview(wizardCard)
        let maxContentWidth: CGFloat = 760
        let minContentWidth: CGFloat = 720
        NSLayoutConstraint.activate([
            wizardCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 600),
            wizardCard.widthAnchor.constraint(lessThanOrEqualToConstant: maxContentWidth),
            wizardCard.widthAnchor.constraint(greaterThanOrEqualToConstant: minContentWidth),
            stepProgressRow.widthAnchor.constraint(equalTo: wizardCard.widthAnchor),
        ])

        let wizardStack = Self.embedStack(in: wizardCard, spacing: 10)

        let wizardTabView = NSTabView()
        wizardTabView.tabViewType = .noTabsNoBorder
        wizardTabView.translatesAutoresizingMaskIntoConstraints = false
        wizardStack.addArrangedSubview(wizardTabView)
        NSLayoutConstraint.activate([
            wizardTabView.heightAnchor.constraint(greaterThanOrEqualToConstant: 520),
            wizardTabView.widthAnchor.constraint(equalTo: wizardCard.widthAnchor, constant: -24),
        ])

        let stepOneView = NSView()
        stepOneView.translatesAutoresizingMaskIntoConstraints = false
        let stepOneItem = NSTabViewItem(identifier: "wizard-step-extension")
        stepOneItem.label = "Extension"
        stepOneItem.view = stepOneView
        wizardTabView.addTabViewItem(stepOneItem)

        let stepOneStack = Self.embedScrollableStack(in: stepOneView)
        stepOneStack.spacing = 12
        stepOneStack.edgeInsets = NSEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)

        let extensionCard = Self.makeCard()
        stepOneStack.addArrangedSubview(extensionCard)
        NSLayoutConstraint.activate([
            extensionCard.widthAnchor.constraint(equalTo: stepOneView.widthAnchor, constant: -24),
        ])
        let extensionStack = Self.embedStack(in: extensionCard, spacing: 10)

        let extensionTitle = NSTextField(labelWithString: "Step 1: Enable Camera Extension")
        extensionTitle.font = NSFont.systemFont(ofSize: 20, weight: .bold)

        let extensionExplainer = NSTextField(labelWithString: "Order matters: click Enable Extension first. If macOS requests approval, click Open Settings and allow Camera Extension.")
        extensionExplainer.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        extensionExplainer.textColor = .secondaryLabelColor
        extensionExplainer.lineBreakMode = .byWordWrapping
        extensionExplainer.maximumNumberOfLines = 3

        let statusBadge = NSTextField(labelWithString: "Idle")
        statusBadge.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        statusBadge.alignment = .center
        statusBadge.wantsLayer = true
        statusBadge.layer?.cornerRadius = 8
        statusBadge.layer?.masksToBounds = true
        statusBadge.backgroundColor = .clear
        statusBadge.drawsBackground = true

        let statusDetailLabel = NSTextField(labelWithString: "Preparing frame server and extension environment...")
        statusDetailLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        statusDetailLabel.textColor = .secondaryLabelColor
        statusDetailLabel.lineBreakMode = .byWordWrapping
        statusDetailLabel.maximumNumberOfLines = 2

        let extensionSetupHintLabel = NSTextField(labelWithString: "1) Click Enable Extension. 2) If prompted, open Settings to approve.")
        extensionSetupHintLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        extensionSetupHintLabel.textColor = .secondaryLabelColor
        extensionSetupHintLabel.lineBreakMode = .byWordWrapping
        extensionSetupHintLabel.maximumNumberOfLines = 2

        let extensionActionRow = NSStackView()
        extensionActionRow.orientation = .horizontal
        extensionActionRow.distribution = .fillEqually
        extensionActionRow.spacing = 10

        let enableButton = NSButton(title: "Enable Extension", target: target, action: Selector(("activate:")))
        enableButton.bezelStyle = .rounded
        enableButton.controlSize = .large

        let openSettingsButton = NSButton(title: "Open Settings", target: target, action: Selector(("openExtensionsSettings:")))
        openSettingsButton.bezelStyle = .texturedRounded
        openSettingsButton.controlSize = .large

        let disableButton = NSButton(title: "Disable Extension", target: target, action: Selector(("deactivate:")))
        disableButton.bezelStyle = .texturedRounded
        disableButton.controlSize = .large

        extensionActionRow.addArrangedSubview(enableButton)
        extensionActionRow.addArrangedSubview(openSettingsButton)
        extensionActionRow.addArrangedSubview(disableButton)

        extensionStack.addArrangedSubview(extensionTitle)
        extensionStack.addArrangedSubview(extensionExplainer)
        extensionStack.addArrangedSubview(statusBadge)
        extensionStack.addArrangedSubview(statusDetailLabel)
        extensionStack.addArrangedSubview(extensionSetupHintLabel)
        extensionStack.addArrangedSubview(extensionActionRow)

        let stepTwoView = NSView()
        stepTwoView.translatesAutoresizingMaskIntoConstraints = false
        let stepTwoItem = NSTabViewItem(identifier: "wizard-step-connect")
        stepTwoItem.label = "Connect"
        stepTwoItem.view = stepTwoView
        wizardTabView.addTabViewItem(stepTwoItem)

        let stepTwoStack = Self.embedScrollableStack(in: stepTwoView)
        stepTwoStack.spacing = 12
        stepTwoStack.edgeInsets = NSEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)

        let hostCard = Self.makeCard()
        stepTwoStack.addArrangedSubview(hostCard)
        NSLayoutConstraint.activate([
            hostCard.widthAnchor.constraint(equalTo: stepTwoView.widthAnchor, constant: -24),
        ])
        let hostStack = Self.embedStack(in: hostCard, spacing: 8)

        let hostTitle = NSTextField(labelWithString: "Step 2: Connect Phone")
        hostTitle.font = NSFont.systemFont(ofSize: 20, weight: .bold)

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
        hostControlsRow.distribution = .fillEqually
        hostControlsRow.spacing = 10

        let hostBridgeStartButton = NSButton(title: "Start Host Bridge", target: target, action: Selector(("startHostBridge:")))
        hostBridgeStartButton.bezelStyle = .rounded
        hostBridgeStartButton.controlSize = .large

        let hostBridgeOpenButton = NSButton(title: "Open Host UI", target: target, action: Selector(("openHostBridgeUI:")))
        hostBridgeOpenButton.bezelStyle = .texturedRounded
        hostBridgeOpenButton.controlSize = .large

        hostControlsRow.addArrangedSubview(hostBridgeStartButton)
        hostControlsRow.addArrangedSubview(hostBridgeOpenButton)

        let qrContainer = NSStackView()
        qrContainer.orientation = .horizontal
        qrContainer.alignment = .top
        qrContainer.distribution = .fill
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
            qrImageView.widthAnchor.constraint(equalToConstant: 168),
            qrImageView.heightAnchor.constraint(equalToConstant: 168),
        ])

        let qrInfoStack = NSStackView()
        qrInfoStack.orientation = .vertical
        qrInfoStack.spacing = 4

        let qrTitleLabel = NSTextField(labelWithString: "Phone Pairing QR")
        qrTitleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)

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

        let divider = NSBox()
        divider.boxType = .separator

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
        resourceControlsRow.distribution = .fillEqually
        resourceControlsRow.spacing = 10

        let syncResourceButton = NSButton(title: "Refresh Status", target: target, action: Selector(("syncHostResourceStatus:")))
        syncResourceButton.bezelStyle = .texturedRounded
        syncResourceButton.controlSize = .large
        resourceControlsRow.addArrangedSubview(syncResourceButton)

        hostStack.addArrangedSubview(hostTitle)
        hostStack.addArrangedSubview(hostBridgeBadge)
        hostStack.addArrangedSubview(hostBridgeDetailLabel)
        hostStack.addArrangedSubview(hostControlsRow)
        hostStack.addArrangedSubview(qrContainer)
        hostStack.addArrangedSubview(divider)
        hostStack.addArrangedSubview(resourceStatusBadge)
        hostStack.addArrangedSubview(phoneIdentityLabel)
        hostStack.addArrangedSubview(resourceIssuesLabel)
        hostStack.addArrangedSubview(cameraRow)
        hostStack.addArrangedSubview(microphoneRow)
        hostStack.addArrangedSubview(speakerRow)
        hostStack.addArrangedSubview(lensRow)
        hostStack.addArrangedSubview(orientationRow)
        hostStack.addArrangedSubview(resourceControlsRow)

        let stepThreeView = NSView()
        stepThreeView.translatesAutoresizingMaskIntoConstraints = false
        let stepThreeItem = NSTabViewItem(identifier: "wizard-step-runtime")
        stepThreeItem.label = "Runtime"
        stepThreeItem.view = stepThreeView
        wizardTabView.addTabViewItem(stepThreeItem)

        let stepThreeStack = Self.embedScrollableStack(in: stepThreeView)
        stepThreeStack.spacing = 12
        stepThreeStack.edgeInsets = NSEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)

        let runtimeCard = Self.makeCard()
        stepThreeStack.addArrangedSubview(runtimeCard)
        NSLayoutConstraint.activate([
            runtimeCard.widthAnchor.constraint(equalTo: stepThreeView.widthAnchor, constant: -24),
        ])
        let runtimeStack = Self.embedStack(in: runtimeCard, spacing: 10)

        let runtimeTitle = NSTextField(labelWithString: "Step 3: Runtime Monitor")
        runtimeTitle.font = NSFont.systemFont(ofSize: 20, weight: .bold)

        let runtimeHelp = NSTextField(labelWithString: "Use this screen while testing. Logs remain scrollable and update live.")
        runtimeHelp.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        runtimeHelp.textColor = .secondaryLabelColor

        let streamDemandLabel = NSTextField(labelWithString: "Capture demand: unknown")
        streamDemandLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        streamDemandLabel.textColor = .secondaryLabelColor

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

        let logScroll = NSScrollView()
        logScroll.hasVerticalScroller = true
        logScroll.autohidesScrollers = false
        logScroll.hasHorizontalScroller = false
        logScroll.borderType = .bezelBorder
        logScroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            logScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 360),
        ])

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.string = "Phone AV Bridge Camera initialized.\n"
        if let textContainer = textView.textContainer {
            textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
            textContainer.widthTracksTextView = true
        }
        logScroll.documentView = textView

        runtimeStack.addArrangedSubview(runtimeTitle)
        runtimeStack.addArrangedSubview(runtimeHelp)
        runtimeStack.addArrangedSubview(streamDemandLabel)
        runtimeStack.addArrangedSubview(logsHeader)
        runtimeStack.addArrangedSubview(logScroll)

        let wizardNavRow = NSStackView()
        wizardNavRow.orientation = .horizontal
        wizardNavRow.alignment = .centerY
        wizardNavRow.distribution = .equalSpacing

        let wizardBackButton = NSButton(title: "Back", target: target, action: Selector(("previousWizardStep:")))
        wizardBackButton.bezelStyle = .rounded
        wizardBackButton.controlSize = .large

        let wizardNextButton = NSButton(title: "Next", target: target, action: Selector(("nextWizardStep:")))
        wizardNextButton.bezelStyle = .rounded
        wizardNextButton.controlSize = .large

        wizardNavRow.addArrangedSubview(wizardBackButton)
        wizardNavRow.addArrangedSubview(wizardNextButton)
        wizardStack.addArrangedSubview(wizardNavRow)

        return CameraMainViewRefs(
            wizardTabView: wizardTabView,
            wizardBackButton: wizardBackButton,
            wizardNextButton: wizardNextButton,
            stepOneChip: stepOneChip,
            stepTwoChip: stepTwoChip,
            stepThreeChip: stepThreeChip,
            extensionSetupHintLabel: extensionSetupHintLabel,
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

    private static func makeCard() -> NSBox {
        let card = NSBox()
        card.boxType = .custom
        card.cornerRadius = 12
        card.fillColor = NSColor.controlBackgroundColor
        card.borderColor = NSColor.separatorColor
        card.borderWidth = 1
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }

    private static func makeStepChip(_ title: String) -> NSTextField {
        let chip = NSTextField(labelWithString: "  \(title)  ")
        chip.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        chip.alignment = .center
        chip.wantsLayer = true
        chip.layer?.cornerRadius = 8
        chip.layer?.masksToBounds = true
        chip.drawsBackground = true
        chip.backgroundColor = .clear
        chip.textColor = .white
        chip.layer?.backgroundColor = NSColor.systemGray.cgColor
        return chip
    }

    private static func embedStack(in card: NSBox, spacing: CGFloat) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false

        if let contentView = card.contentView {
            contentView.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
                stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
                stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
                stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            ])
        }

        return stack
    }

    private static func embedScrollableStack(in container: NSView) -> NSStackView {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = stack

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])

        return stack
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
