//
//  ViewController.swift
//  samplecamera
//
//  Created by laurent denoue on 7/1/22.
//

import AVFoundation
import Cocoa
import CoreMediaIO
import CoreImage
import Network
import SystemExtensions

class ViewController: NSViewController {
    private let framePort: UInt16 = 39501
    private let frameWidth = Int(fixedCamWidth)
    private let frameHeight = Int(fixedCamHeight)
    private let frameBytes = Int(fixedCamWidth * fixedCamHeight * 4)
    private let frameQueue = DispatchQueue(label: "org.autobyteus.phoneavbridge.camera.frames")
    private let frameStateQueue = DispatchQueue(label: "org.autobyteus.phoneavbridge.camera.frame-state")
    private var frameListener: NWListener?
    private var frameConnection: NWConnection?
    private var latestFrame: Data?

    private var statusBadge: NSTextField!
    private var statusDetailLabel: NSTextField!
    private var streamDemandLabel: NSTextField!
    private var hostBridgeBadge: NSTextField!
    private var hostBridgeDetailLabel: NSTextField!
    private var hostBridgeStartButton: NSButton!
    private var hostBridgeOpenButton: NSButton!
    private var qrStatusLabel: NSTextField!
    private var qrExpiryLabel: NSTextField!
    private var qrImageView: NSImageView!
    private var qrRegenerateButton: NSButton!
    private var qrCopyPayloadButton: NSButton!
    private var resourceStatusBadge: NSTextField!
    private var phoneIdentityLabel: NSTextField!
    private var resourceIssuesLabel: NSTextField!
    private var cameraStatusChip: NSTextField!
    private var microphoneStatusChip: NSTextField!
    private var speakerStatusChip: NSTextField!
    private var cameraLensValueLabel: NSTextField!
    private var cameraOrientationValueLabel: NSTextField!
    private var syncResourceButton: NSButton!
    private var logTextView: NSTextView!
    private var needToStream: Bool = false
    private var mirrorCamera: Bool = false
    private var image = NSImage(named: "cham-index")
    private var activating: Bool = false
    private var readyToEnqueue = false
    private var enqueued = false
    private var _videoDescription: CMFormatDescription!
    private var _bufferPool: CVPixelBufferPool!
    private var _bufferAuxAttributes: NSDictionary!
    private var _whiteStripeStartRow: UInt32 = 0
    private var _whiteStripeIsAscending: Bool = false
    private var overlayMessage: Bool = false
    private var sequenceNumber = 0
    private var timer: Timer?
    private var propTimer: Timer?
    private var hostBridgeTimer: Timer?
    private var hostBridgeIsRunning = false
    private var hostBridgeAutoStartAttempted = false
    private var latestHostResourceStatus: HostBridgeClient.HostStatusSnapshot?
    private var latestQrPayloadText: String?
    private lazy var hostBridgeClient = HostBridgeClient(baseURL: hostBridgeBaseURL)
    private var qrTokenCoordinator: QrTokenCoordinator?
    private var didSetInitialStatus = false

    func activateCamera() {
        guard let extensionIdentifier = ViewController._extensionBundle().bundleIdentifier else {
            return
        }
        self.activating = true
        let activationRequest = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: extensionIdentifier, queue: .main)
        activationRequest.delegate = self
        OSSystemExtensionManager.shared.submitRequest(activationRequest)
    }

    private typealias HostResourceStatus = HostBridgeClient.HostStatusSnapshot
    
    func deactivateCamera() {
        guard let extensionIdentifier = ViewController._extensionBundle().bundleIdentifier else {
            return
        }
        self.activating = false
        let deactivationRequest = OSSystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: extensionIdentifier, queue: .main)
        deactivationRequest.delegate = self
        OSSystemExtensionManager.shared.submitRequest(deactivationRequest)
    }
    
    private class func _extensionBundle() -> Bundle {
        let extensionsDirectoryURL = URL(fileURLWithPath: "Contents/Library/SystemExtensions", relativeTo: Bundle.main.bundleURL)
        let extensionURLs: [URL]
        do {
            extensionURLs = try FileManager.default.contentsOfDirectory(at: extensionsDirectoryURL,
                                                                        includingPropertiesForKeys: nil,
                                                                        options: .skipsHiddenFiles)
        } catch let error {
            fatalError("Failed to get the contents of \(extensionsDirectoryURL.absoluteString): \(error.localizedDescription)")
        }
        
        guard let extensionURL = extensionURLs.first else {
            fatalError("Failed to find any system extensions")
        }
        guard let extensionBundle = Bundle(url: extensionURL) else {
            fatalError("Failed to find any system extensions")
        }
        return extensionBundle
    }
    
    func getJustProperty(streamId: CMIOStreamID) -> String? {
        let selector = FourCharCode("just")
        var address = CMIOObjectPropertyAddress(selector, .global, .main)
        let exists = CMIOObjectHasProperty(streamId, &address)
        if exists {
            var dataSize: UInt32 = 0
            var dataUsed: UInt32 = 0
            CMIOObjectGetPropertyDataSize(streamId, &address, 0, nil, &dataSize)
            var name: CFString = "" as NSString
            CMIOObjectGetPropertyData(streamId, &address, 0, nil, dataSize, &dataUsed, &name);
            return name as String
        } else {
            return nil
        }
    }

    func setJustProperty(streamId: CMIOStreamID, newValue: String) {
        let selector = FourCharCode("just")
        var address = CMIOObjectPropertyAddress(selector, .global, .main)
        let exists = CMIOObjectHasProperty(streamId, &address)
        if exists {
            var settable: DarwinBoolean = false
            CMIOObjectIsPropertySettable(streamId,&address,&settable)
            if settable == false {
                return
            }
            var dataSize: UInt32 = 0
            CMIOObjectGetPropertyDataSize(streamId, &address, 0, nil, &dataSize)
            var newName: CFString = newValue as NSString
            CMIOObjectSetPropertyData(streamId, &address, 0, nil, dataSize, &newName)
        }
    }

    func makeDevicesVisible(){
        var prop = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var allow : UInt32 = 1
        let dataSize : UInt32 = 4
        let zero : UInt32 = 0
        CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &prop, zero, nil, dataSize, &allow)
    }

    var sourceStream: CMIOStreamID?
    var sinkStream: CMIOStreamID?
    var sinkQueue: CMSimpleQueue?

    func startFrameServer() {
        guard frameListener == nil else { return }
        do {
            let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: framePort)!)
            listener.newConnectionHandler = { [weak self] connection in
                self?.acceptFrameConnection(connection)
            }
            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.showMessage("frame server ready on 127.0.0.1:\(self?.framePort ?? 0)")
                    self?.updateStatusBadge("Ready", color: .systemGreen)
                case .failed(let error):
                    self?.showMessage("frame server failed: \(error.localizedDescription)")
                    self?.updateStatusBadge("Error", color: .systemRed)
                default:
                    break
                }
            }
            listener.start(queue: frameQueue)
            frameListener = listener
        } catch {
            showMessage("frame server start error: \(error.localizedDescription)")
            updateStatusBadge("Error", color: .systemRed)
        }
    }

    func stopFrameServer() {
        frameConnection?.cancel()
        frameConnection = nil
        frameListener?.cancel()
        frameListener = nil
    }

    private func acceptFrameConnection(_ connection: NWConnection) {
        frameConnection?.cancel()
        frameConnection = connection
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state {
                self?.showMessage("frame connection failed: \(error.localizedDescription)")
                self?.updateStatusBadge("Warning", color: .systemOrange)
            }
        }
        connection.start(queue: frameQueue)
        receiveFrameChunks(connection: connection, pending: Data())
    }

    private func receiveFrameChunks(connection: NWConnection, pending: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let error = error {
                self.showMessage("frame receive error: \(error.localizedDescription)")
                return
            }

            var buffer = pending
            if let data = data, !data.isEmpty {
                buffer.append(data)
            }

            while buffer.count >= self.frameBytes {
                let frame = Data(buffer.prefix(self.frameBytes))
                buffer.removeFirst(self.frameBytes)
                self.frameStateQueue.async {
                    self.latestFrame = frame
                }
            }

            if isComplete {
                self.showMessage("frame connection closed")
                self.updateStatusBadge("Idle", color: .systemOrange)
                return
            }

            self.receiveFrameChunks(connection: connection, pending: buffer)
        }
    }
    
    func initSink(deviceId: CMIODeviceID, sinkStream: CMIOStreamID) {
        let dims = CMVideoDimensions(width: fixedCamWidth, height: fixedCamHeight)
        CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCVPixelFormatType_32BGRA,
            width: dims.width, height: dims.height, extensions: nil, formatDescriptionOut: &_videoDescription)
        
        var pixelBufferAttributes: NSDictionary!
           pixelBufferAttributes = [
                kCVPixelBufferWidthKey: dims.width,
                kCVPixelBufferHeightKey: dims.height,
                kCVPixelBufferPixelFormatTypeKey: _videoDescription.mediaSubType,
                kCVPixelBufferIOSurfacePropertiesKey: [:]
            ]
        
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, pixelBufferAttributes, &_bufferPool)

        let pointerQueue = UnsafeMutablePointer<Unmanaged<CMSimpleQueue>?>.allocate(capacity: 1)
        // see https://stackoverflow.com/questions/53065186/crash-when-accessing-refconunsafemutablerawpointer-inside-cgeventtap-callback
        //let pointerRef = UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque())
        let pointerRef = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let result = CMIOStreamCopyBufferQueue(sinkStream, {
            (sinkStream: CMIOStreamID, buf: UnsafeMutableRawPointer?, refcon: UnsafeMutableRawPointer?) in
            let sender = Unmanaged<ViewController>.fromOpaque(refcon!).takeUnretainedValue()
            sender.readyToEnqueue = true
        },pointerRef,pointerQueue)
        if result != 0 {
            showMessage("error starting sink")
        } else {
            if let queue = pointerQueue.pointee {
                self.sinkQueue = queue.takeUnretainedValue()
            }
            let resultStart = CMIODeviceStartStream(deviceId, sinkStream) == 0
            if resultStart {
                showMessage("initSink started")
            } else {
                showMessage("initSink error startstream")
                updateStatusBadge("Error", color: .systemRed)
            }
        }
    }

    func getDevice(name: String) -> AVCaptureDevice? {
        print("getDevice name=",name)
        var devices: [AVCaptureDevice]?
        if #available(macOS 10.15, *) {
            let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.externalUnknown],
                                                                    mediaType: .video,
                                                                    position: .unspecified)
            devices = discoverySession.devices
        } else {
            // Fallback on earlier versions
            devices = AVCaptureDevice.devices(for: .video)
        }
        guard let devices = devices else { return nil }
        return devices.first { $0.localizedName == name}
    }

    func getCMIODevice(uid: String) -> CMIOObjectID? {
        var dataSize: UInt32 = 0
        var devices = [CMIOObjectID]()
        var dataUsed: UInt32 = 0
        var opa = CMIOObjectPropertyAddress(CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices), .global, .main)
        CMIOObjectGetPropertyDataSize(CMIOObjectPropertySelector(kCMIOObjectSystemObject), &opa, 0, nil, &dataSize);
        let nDevices = Int(dataSize) / MemoryLayout<CMIOObjectID>.size
        devices = [CMIOObjectID](repeating: 0, count: Int(nDevices))
        CMIOObjectGetPropertyData(CMIOObjectPropertySelector(kCMIOObjectSystemObject), &opa, 0, nil, dataSize, &dataUsed, &devices);
        for deviceObjectID in devices {
            opa.mSelector = CMIOObjectPropertySelector(kCMIODevicePropertyDeviceUID)
            CMIOObjectGetPropertyDataSize(deviceObjectID, &opa, 0, nil, &dataSize)
            var name: CFString = "" as NSString
            //CMIOObjectGetPropertyData(deviceObjectID, &opa, 0, nil, UInt32(MemoryLayout<CFString>.size), &dataSize, &name);
            CMIOObjectGetPropertyData(deviceObjectID, &opa, 0, nil, dataSize, &dataUsed, &name);
            if String(name) == uid {
                return deviceObjectID
            }
        }
        return nil
    }

    func getInputStreams(deviceId: CMIODeviceID) -> [CMIOStreamID]
    {
        var dataSize: UInt32 = 0
        var dataUsed: UInt32 = 0
        var opa = CMIOObjectPropertyAddress(CMIOObjectPropertySelector(kCMIODevicePropertyStreams), .global, .main)
        CMIOObjectGetPropertyDataSize(deviceId, &opa, 0, nil, &dataSize);
        let numberStreams = Int(dataSize) / MemoryLayout<CMIOStreamID>.size
        var streamIds = [CMIOStreamID](repeating: 0, count: numberStreams)
        CMIOObjectGetPropertyData(deviceId, &opa, 0, nil, dataSize, &dataUsed, &streamIds)
        return streamIds
    }
    func connectToCamera() {
        if let device = getDevice(name: cameraName), let deviceObjectId = getCMIODevice(uid: device.uniqueID) {
            let streamIds = getInputStreams(deviceId: deviceObjectId)
            if streamIds.count == 2 {
                sinkStream = streamIds[1]
                showMessage("found sink stream")
                initSink(deviceId: deviceObjectId, sinkStream: streamIds[1])
            }
            if let firstStream = streamIds.first {
                showMessage("found source stream")
                sourceStream = firstStream
                let current = statusBadge.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if current == "Starting" || current == "Idle" {
                    updateStatusBadge("Enabled", color: .systemGreen)
                }
            }
        }
    }
    
    @objc func activate(_ sender: Any? = nil) {
        activateCamera()
    }

    @objc func deactivate(_ sender: Any? = nil) {
        deactivateCamera()
    }

    func registerForDeviceNotifications() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name.AVCaptureDeviceWasConnected, object: nil, queue: nil) { (notif) -> Void in
            // when the user click "activate", we will receive a notification
            // we can then try to connect to our "Sample Camera" (if not already connected to)
            if self.sourceStream == nil {
                self.connectToCamera()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureInterface()
        configureQrCoordinator()
        registerForDeviceNotifications()
        refreshHostBridgeStatus(autoStartIfNeeded: true)
        hostBridgeTimer?.invalidate()
        hostBridgeTimer = Timer.scheduledTimer(timeInterval: 2.5, target: self, selector: #selector(hostBridgeHeartbeat), userInfo: nil, repeats: true)

        startFrameServer()
        self.makeDevicesVisible()
        connectToCamera()
        if sourceStream == nil {
            activateCamera()
        }
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 1/30.0, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
        propTimer?.invalidate()
        propTimer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(propertyTimer), userInfo: nil, repeats: true)
        let currentBadge = statusBadge.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentBadge != "Enabled" && currentBadge != "Streaming" {
            updateStatusBadge("Starting", color: .systemOrange)
        }
        streamDemandLabel.stringValue = "Capture demand: waiting for client"
        DispatchQueue.main.async {
            self.view.window?.title = "Phone AV Bridge Camera"
            self.view.window?.minSize = NSSize(width: 900, height: 620)
            if !self.didSetInitialStatus {
                self.statusDetailLabel.stringValue = "Keep this app open. Then approve the camera extension once in System Settings."
                self.didSetInitialStatus = true
            }
        }
    }

    func showMessage(_ text: String) {
        print("showMessage",text)
        let timestamp = Self.logTimestampFormatter.string(from: Date())
        let line = "[\(timestamp)] \(text)\n"
        DispatchQueue.main.async {
            self.logTextView.textStorage?.append(NSAttributedString(string: line))
            self.logTextView.scrollToEndOfDocument(nil)
            self.statusDetailLabel.stringValue = text
        }
    }
    func enqueue(_ queue: CMSimpleQueue, _ image: CGImage) {
        guard CMSimpleQueueGetCount(queue) < CMSimpleQueueGetCapacity(queue) else {
            print("error enqueuing")
            return
        }
        var err: OSStatus = 0
        var pixelBuffer: CVPixelBuffer?
        err = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, self._bufferPool, self._bufferAuxAttributes, &pixelBuffer)
        if let pixelBuffer = pixelBuffer {
            
            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            
            /*var bufferPtr = CVPixelBufferGetBaseAddress(pixelBuffer)!
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
            memset(bufferPtr, 0, rowBytes * height)
            
            let whiteStripeStartRow = self._whiteStripeStartRow
            if self._whiteStripeIsAscending {
                self._whiteStripeStartRow = whiteStripeStartRow - 1
                self._whiteStripeIsAscending = self._whiteStripeStartRow > 0
            }
            else {
                self._whiteStripeStartRow = whiteStripeStartRow + 1
                self._whiteStripeIsAscending = self._whiteStripeStartRow >= (height - kWhiteStripeHeight)
            }
            bufferPtr += rowBytes * Int(whiteStripeStartRow)
            for _ in 0..<kWhiteStripeHeight {
                for _ in 0..<width {
                    var white: UInt32 = 0xFFFFFFFF
                    memcpy(bufferPtr, &white, MemoryLayout.size(ofValue: white))
                    bufferPtr += MemoryLayout.size(ofValue: white)
                }
            }*/
            let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
            // optimizing context: interpolationQuality and bitmapInfo
            // see https://stackoverflow.com/questions/7560979/cgcontextdrawimage-is-extremely-slow-after-large-uiimage-drawn-into-it
            if let context = CGContext(data: pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                      space: rgbColorSpace,
                                      //bitmapInfo: UInt32(CGImageAlphaInfo.noneSkipFirst.rawValue) | UInt32(CGImageByteOrderInfo.order32Little.rawValue))
                                       bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
            {
                context.interpolationQuality = .low
                if mirrorCamera {
                    context.translateBy(x: CGFloat(width), y: 0.0)
                    context.scaleBy(x: -1.0, y: 1.0)
                }
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            
            var sbuf: CMSampleBuffer!
            var timingInfo = CMSampleTimingInfo()
            timingInfo.presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock())
            err = CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: self._videoDescription, sampleTiming: &timingInfo, sampleBufferOut: &sbuf)
            if err == 0 {
                if let sbuf = sbuf {
                    let pointerRef = UnsafeMutableRawPointer(Unmanaged.passRetained(sbuf).toOpaque())
                    CMSimpleQueueEnqueue(queue, element: pointerRef)
                }
            }
        } else {
            print("error getting pixel buffer")
        }
    }

    func enqueueBGRA(_ queue: CMSimpleQueue, _ frameData: Data) {
        guard frameData.count == frameBytes else {
            return
        }
        guard CMSimpleQueueGetCount(queue) < CMSimpleQueueGetCapacity(queue) else {
            return
        }

        var err: OSStatus = 0
        var pixelBuffer: CVPixelBuffer?
        err = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(
            kCFAllocatorDefault,
            self._bufferPool,
            self._bufferAuxAttributes,
            &pixelBuffer
        )
        guard err == 0, let pixelBuffer = pixelBuffer else {
            return
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
            frameData.withUnsafeBytes { src in
                guard let srcBase = src.baseAddress else { return }
                memcpy(baseAddress, srcBase, frameBytes)
            }
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        var sbuf: CMSampleBuffer!
        var timingInfo = CMSampleTimingInfo()
        timingInfo.presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock())
        err = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: self._videoDescription,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sbuf
        )
        if err == 0, let sbuf = sbuf {
            let pointerRef = UnsafeMutableRawPointer(Unmanaged.passRetained(sbuf).toOpaque())
            CMSimpleQueueEnqueue(queue, element: pointerRef)
        }
    }
    
    @objc func propertyTimer() {
        if let sourceStream = sourceStream {
            self.setJustProperty(streamId: sourceStream, newValue: "random")
            let just = self.getJustProperty(streamId: sourceStream)
            if let just = just {
                if just == "sc=1" {
                    needToStream = true
                } else {
                    needToStream = false
                }
            }
            DispatchQueue.main.async {
                if self.needToStream {
                    self.streamDemandLabel.stringValue = "Capture demand: active"
                    self.streamDemandLabel.textColor = .systemGreen
                    self.updateStatusBadge("Streaming", color: .systemGreen)
                } else {
                    self.streamDemandLabel.stringValue = "Capture demand: idle"
                    self.streamDemandLabel.textColor = .secondaryLabelColor
                    let current = self.statusBadge.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if current == "Starting" || current == "Idle" {
                        self.updateStatusBadge("Enabled", color: .systemGreen)
                    }
                }
            }
        }
    }
    @objc func fireTimer() {
        if needToStream {
            if (enqueued == false || readyToEnqueue == true), let queue = self.sinkQueue {
                enqueued = true
                readyToEnqueue = false
                var frame: Data?
                frameStateQueue.sync {
                    frame = latestFrame
                }
                if let frame = frame {
                    self.enqueueBGRA(queue, frame)
                } else if let image = image, let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    self.enqueue(queue, cgImage)
                }
            }
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    deinit {
        stopFrameServer()
        timer?.invalidate()
        propTimer?.invalidate()
        hostBridgeTimer?.invalidate()
        qrTokenCoordinator?.stop(reason: "view-controller-deinit")
    }


}

private extension ViewController {
    static let logTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var hostBridgeBaseURL: URL {
        URL(string: "http://127.0.0.1:8787")!
    }

    func configureQrCoordinator() {
        let coordinator = QrTokenCoordinator(
            hostBridgeClient: hostBridgeClient,
            isHostOnline: { [weak self] in self?.hostBridgeIsRunning == true }
        )
        coordinator.onSnapshot = { [weak self] snapshot, manual in
            self?.applyQrToken(snapshot, manual: manual)
        }
        coordinator.onExpiryTick = { [weak self] text in
            self?.qrExpiryLabel.stringValue = text
        }
        coordinator.onError = { [weak self] message in
            guard let self else { return }
            self.qrStatusLabel.stringValue = message
            self.qrExpiryLabel.stringValue = "Check host bridge logs and retry."
            self.qrRegenerateButton.isEnabled = self.hostBridgeIsRunning
            self.showMessage(message)
        }
        coordinator.onLog = { [weak self] line in
            self?.showMessage(line)
        }
        qrTokenCoordinator = coordinator
    }

    @objc func hostBridgeHeartbeat() {
        refreshHostBridgeStatus(autoStartIfNeeded: false)
    }

    func hostBridgeAppCandidates() -> [URL] {
        var candidates: [URL] = []
        if let discovered = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "org.autobyteus.phoneavbridge.host") {
            candidates.append(discovered)
        }

        let username = NSUserName()
        let explicitPaths = [
            "/Users/\(username)/Applications/Phone AV Bridge Host.app",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Phone AV Bridge Host.app").path,
            "/Applications/Phone AV Bridge Host.app",
        ]
        for path in explicitPaths {
            let url = URL(fileURLWithPath: path)
            if !candidates.contains(url) {
                candidates.append(url)
            }
        }
        return candidates
    }

    func checkHostBridgeHealth(completion: @escaping (Bool) -> Void) {
        hostBridgeClient.health(completion: completion)
    }

    func refreshHostBridgeStatus(autoStartIfNeeded: Bool) {
        checkHostBridgeHealth { [weak self] running in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let transitioned = running != self.hostBridgeIsRunning
                self.hostBridgeIsRunning = running

                if running {
                    self.updateHostBridgeBadge("Online", color: .systemGreen)
                    self.hostBridgeDetailLabel.stringValue = "Host discovery + pairing service is running (port 8787 / UDP 39888)."
                    self.hostBridgeStartButton.title = "Restart Host Bridge"
                    self.refreshHostResourceStatus()
                    if transitioned || self.latestQrPayloadText == nil {
                        self.qrStatusLabel.stringValue = "Generating QR token…"
                        self.qrRegenerateButton.isEnabled = false
                        self.qrTokenCoordinator?.refresh(manual: false)
                    }
                    if transitioned {
                        self.showMessage("host bridge online at \(self.hostBridgeBaseURL.absoluteString)")
                    }
                } else {
                    self.updateHostBridgeBadge("Offline", color: .systemOrange)
                    self.hostBridgeDetailLabel.stringValue = "Host bridge is not running. Android cannot pair/discover until started."
                    self.hostBridgeStartButton.title = "Start Host Bridge"
                    self.qrTokenCoordinator?.stop(reason: "host-offline")
                    self.resetQrSection(bridgeOnline: false)
                    self.resetHostResourceSection(bridgeOnline: false)
                    if transitioned {
                        self.showMessage("host bridge offline")
                    }
                    if autoStartIfNeeded, !self.hostBridgeAutoStartAttempted {
                        self.hostBridgeAutoStartAttempted = true
                        self.startHostBridge(nil)
                    }
                }
            }
        }
    }

    func updateHostBridgeBadge(_ title: String, color: NSColor) {
        DispatchQueue.main.async {
            self.hostBridgeBadge.stringValue = "  \(title)  "
            self.hostBridgeBadge.textColor = .white
            self.hostBridgeBadge.layer?.backgroundColor = color.cgColor
        }
    }

    @objc func startHostBridge(_ sender: Any?) {
        checkHostBridgeHealth { [weak self] running in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if running {
                    self.showMessage("host bridge already running")
                    self.refreshHostBridgeStatus(autoStartIfNeeded: false)
                    return
                }

                for appURL in self.hostBridgeAppCandidates() {
                    if FileManager.default.fileExists(atPath: appURL.path) {
                        let configuration = NSWorkspace.OpenConfiguration()
                        configuration.activates = false
                        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                self.refreshHostBridgeStatus(autoStartIfNeeded: false)
                            }
                            if let error = error {
                                self.showMessage("failed to start host bridge app: \(error.localizedDescription)")
                            } else {
                                self.showMessage("started Phone AV Bridge Host")
                            }
                        }
                        return
                    }
                }
                self.showMessage("Phone AV Bridge Host app not found. Install it first, then retry.")
            }
        }
    }

    @objc func openHostBridgeUI(_ sender: Any?) {
        if NSWorkspace.shared.open(hostBridgeBaseURL) {
            showMessage("Opened host bridge UI at \(hostBridgeBaseURL.absoluteString)")
        } else {
            showMessage("Unable to open host bridge UI. Start Phone AV Bridge Host first.")
        }
    }

    private func imageFromQrDataUrl(_ dataUrl: String?) -> NSImage? {
        guard let dataUrl = dataUrl, let commaIndex = dataUrl.firstIndex(of: ",") else {
            return nil
        }
        let encoded = String(dataUrl[dataUrl.index(after: commaIndex)...])
        guard let data = Data(base64Encoded: encoded, options: .ignoreUnknownCharacters) else {
            return nil
        }
        return NSImage(data: data)
    }

    private func imageFromQrPayloadText(_ payloadText: String?) -> NSImage? {
        guard let payloadText = payloadText, let data = payloadText.data(using: .utf8) else {
            return nil
        }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else {
            return nil
        }

        let transformed = output.transformed(by: CGAffineTransform(scaleX: 6, y: 6))
        let rep = NSCIImageRep(ciImage: transformed)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }

    private func applyQrToken(_ qrToken: HostBridgeClient.QrTokenSnapshot, manual: Bool) {
        latestQrPayloadText = qrToken.payloadText?.isEmpty == false ? qrToken.payloadText : nil

        if let image = imageFromQrDataUrl(qrToken.qrImageDataUrl) {
            qrImageView.image = image
        } else if let image = imageFromQrPayloadText(latestQrPayloadText) {
            qrImageView.image = image
        } else {
            qrImageView.image = nil
        }

        qrStatusLabel.stringValue = manual
            ? "QR regenerated. Scan in Android: Pair via QR."
            : "Scan in Android: Pair via QR."
        qrCopyPayloadButton.isEnabled = latestQrPayloadText != nil
        qrRegenerateButton.isEnabled = true
    }

    @objc func regenerateQrToken(_ sender: Any?) {
        qrStatusLabel.stringValue = "Regenerating QR token…"
        qrRegenerateButton.isEnabled = false
        qrTokenCoordinator?.refresh(manual: true)
    }

    @objc func copyQrPayload(_ sender: Any?) {
        guard let payloadText = qrTokenCoordinator?.latestPayloadText ?? latestQrPayloadText else {
            qrStatusLabel.stringValue = "No QR payload available to copy."
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let ok = pasteboard.setString(payloadText, forType: .string)
        if ok {
            qrStatusLabel.stringValue = "QR payload copied to clipboard."
        } else {
            qrStatusLabel.stringValue = "Clipboard copy failed."
        }
    }

    func resetQrSection(bridgeOnline: Bool) {
        latestQrPayloadText = nil
        qrImageView.image = nil
        qrCopyPayloadButton.isEnabled = false
        qrRegenerateButton.isEnabled = bridgeOnline
        if bridgeOnline {
            qrStatusLabel.stringValue = "Generating QR token…"
            qrExpiryLabel.stringValue = "Expiry: waiting"
        } else {
            qrStatusLabel.stringValue = "Host bridge offline. Start host bridge to generate QR."
            qrExpiryLabel.stringValue = "Expiry: unavailable"
        }
    }

    func updateResourceStatusBadge(_ title: String, color: NSColor) {
        DispatchQueue.main.async {
            self.resourceStatusBadge.stringValue = "  \(title)  "
            self.resourceStatusBadge.textColor = .white
            self.resourceStatusBadge.layer?.backgroundColor = color.cgColor
        }
    }

    private func updateResourceChip(_ chip: NSTextField, title: String, color: NSColor) {
        chip.stringValue = "  \(title)  "
        chip.textColor = .white
        chip.layer?.backgroundColor = color.cgColor
    }

    private func resourceHasIssue(_ resource: String, issues: [String]) -> Bool {
        let prefix = "\(resource.lowercased()):"
        return issues.contains(where: { $0.lowercased().hasPrefix(prefix) })
    }

    private func updateResourceChipStates(from status: HostResourceStatus) {
        if !status.cameraAvailable {
            updateResourceChip(cameraStatusChip, title: "Unavailable", color: .systemGray)
        } else if resourceHasIssue("camera", issues: status.issues) {
            updateResourceChip(cameraStatusChip, title: "Issue", color: .systemOrange)
        } else if status.camera {
            updateResourceChip(cameraStatusChip, title: "Active", color: .systemGreen)
        } else {
            updateResourceChip(cameraStatusChip, title: "Off", color: .systemGray)
        }

        if !status.microphoneAvailable {
            updateResourceChip(microphoneStatusChip, title: "Unavailable", color: .systemGray)
        } else if resourceHasIssue("microphone", issues: status.issues) {
            updateResourceChip(microphoneStatusChip, title: "Issue", color: .systemOrange)
        } else if status.microphone {
            updateResourceChip(microphoneStatusChip, title: "Active", color: .systemGreen)
        } else {
            updateResourceChip(microphoneStatusChip, title: "Off", color: .systemGray)
        }

        if !status.speakerAvailable {
            updateResourceChip(speakerStatusChip, title: "Unavailable", color: .systemGray)
        } else if resourceHasIssue("speaker", issues: status.issues) {
            updateResourceChip(speakerStatusChip, title: "Issue", color: .systemOrange)
        } else if status.speaker {
            updateResourceChip(speakerStatusChip, title: "Active", color: .systemGreen)
        } else {
            updateResourceChip(speakerStatusChip, title: "Off", color: .systemGray)
        }
    }

    func resetHostResourceSection(bridgeOnline: Bool) {
        let detail = bridgeOnline
            ? "Waiting for phone pair state from host service..."
            : "Host bridge offline. Phone session status unavailable."
        phoneIdentityLabel.stringValue = detail
        resourceIssuesLabel.stringValue = "Issues: n/a"
        cameraLensValueLabel.stringValue = "Unknown"
        cameraOrientationValueLabel.stringValue = "Unknown"
        updateResourceChip(cameraStatusChip, title: "Unavailable", color: .systemGray)
        updateResourceChip(microphoneStatusChip, title: "Unavailable", color: .systemGray)
        updateResourceChip(speakerStatusChip, title: "Unavailable", color: .systemGray)
        syncResourceButton.isEnabled = bridgeOnline
        updateResourceStatusBadge(bridgeOnline ? "Checking" : "Unavailable", color: .systemOrange)
        latestHostResourceStatus = nil
    }

    private func fetchHostResourceStatus(completion: @escaping (HostResourceStatus?) -> Void) {
        hostBridgeClient.fetchStatus { result in
            switch result {
            case .success(let status):
                completion(status)
            case .failure:
                completion(nil)
            }
        }
    }

    func refreshHostResourceStatus() {
        fetchHostResourceStatus { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard let status = status else {
                    self.resetHostResourceSection(bridgeOnline: true)
                    self.showMessage("host status read failed")
                    return
                }

                self.latestHostResourceStatus = status
                let hasIssues = !status.issues.isEmpty
                if !status.paired {
                    self.updateResourceStatusBadge("Not Paired", color: .systemOrange)
                } else if hasIssues {
                    self.updateResourceStatusBadge("Needs Attention", color: .systemOrange)
                } else if status.camera || status.microphone || status.speaker {
                    self.updateResourceStatusBadge("Resource Active", color: .systemGreen)
                } else {
                    self.updateResourceStatusBadge("Paired", color: .systemGreen)
                }

                let name = (status.phoneName?.isEmpty == false) ? status.phoneName! : "unknown"
                let identifier = (status.phoneId?.isEmpty == false) ? status.phoneId! : "unknown"
                self.phoneIdentityLabel.stringValue = "Phone: \(name) (\(identifier)) | Host state: \(status.hostStatus)"
                self.resourceIssuesLabel.stringValue = status.issues.isEmpty ? "Issues: none" : "Issues: \(status.issues.joined(separator: " | "))"
                self.cameraLensValueLabel.stringValue = status.cameraLens == "front" ? "Front" : "Back"
                self.cameraOrientationValueLabel.stringValue = self.orientationModeDisplayName(status.cameraOrientationMode)
                self.updateResourceChipStates(from: status)
                self.syncResourceButton.isEnabled = true
            }
        }
    }

    private func orientationModeDisplayName(_ raw: String) -> String {
        switch raw {
        case "portrait_lock":
            return "Portrait Lock"
        case "landscape_lock":
            return "Landscape Lock"
        default:
            return "Auto"
        }
    }

    @objc func syncHostResourceStatus(_ sender: Any?) {
        if !hostBridgeIsRunning {
            showMessage("Cannot sync phone session: host bridge offline")
            return
        }
        refreshHostResourceStatus()
    }

    func configureInterface() {
        let refs = CameraMainViewBuilder().build(in: view, target: self)
        statusBadge = refs.statusBadge
        statusDetailLabel = refs.statusDetailLabel
        streamDemandLabel = refs.streamDemandLabel
        hostBridgeBadge = refs.hostBridgeBadge
        hostBridgeDetailLabel = refs.hostBridgeDetailLabel
        hostBridgeStartButton = refs.hostBridgeStartButton
        hostBridgeOpenButton = refs.hostBridgeOpenButton
        qrStatusLabel = refs.qrStatusLabel
        qrExpiryLabel = refs.qrExpiryLabel
        qrImageView = refs.qrImageView
        qrRegenerateButton = refs.qrRegenerateButton
        qrCopyPayloadButton = refs.qrCopyPayloadButton
        resourceStatusBadge = refs.resourceStatusBadge
        phoneIdentityLabel = refs.phoneIdentityLabel
        resourceIssuesLabel = refs.resourceIssuesLabel
        cameraStatusChip = refs.cameraStatusChip
        microphoneStatusChip = refs.microphoneStatusChip
        speakerStatusChip = refs.speakerStatusChip
        cameraLensValueLabel = refs.cameraLensValueLabel
        cameraOrientationValueLabel = refs.cameraOrientationValueLabel
        syncResourceButton = refs.syncResourceButton
        logTextView = refs.logTextView

        updateHostBridgeBadge("Offline", color: .systemOrange)
        resetQrSection(bridgeOnline: false)
        resetHostResourceSection(bridgeOnline: false)
        updateStatusBadge("Idle", color: .systemOrange)
    }

    func updateStatusBadge(_ title: String, color: NSColor) {
        DispatchQueue.main.async {
            self.statusBadge.stringValue = "  \(title)  "
            self.statusBadge.textColor = .white
            self.statusBadge.layer?.backgroundColor = color.cgColor
        }
    }

    @objc func clearLog(_ sender: Any?) {
        logTextView.string = ""
    }

    @objc func openExtensionsSettings(_ sender: Any?) {
        let urls = [
            URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"),
            URL(string: "x-apple.systempreferences:")
        ].compactMap { $0 }

        for url in urls {
            if NSWorkspace.shared.open(url) {
                showMessage("Opened System Settings. Navigate to Login Items & Extensions -> Camera Extensions.")
                return
            }
        }
        showMessage("Unable to open System Settings automatically. Open it manually and approve Camera Extensions.")
    }
}

extension ViewController:OSSystemExtensionRequestDelegate
{
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties,
                 withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        showMessage("Replacing extension version \(existing.bundleShortVersion) with \(ext.bundleShortVersion)")
        return .replace
    }
    
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        showMessage("Extension needs user approval")
    }

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        showMessage("Request finished with result: \(result.rawValue)")
        if result == .completed {
            if self.activating {
                showMessage("The camera is activated")
                updateStatusBadge("Enabled", color: .systemGreen)
            } else {
                showMessage("The camera is deactivated")
                updateStatusBadge("Disabled", color: .systemOrange)
            }
        } else {
            if self.activating {
                showMessage("Activation pending system restart.")
                updateStatusBadge("Pending Reboot", color: .systemOrange)
            } else {
                showMessage("Deactivation pending system restart.")
                updateStatusBadge("Pending Reboot", color: .systemOrange)
            }
        }
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        let detail = (error as NSError).localizedDescription
        if self.activating {
            showMessage("Failed to activate the camera: \(detail)")
        } else {
            showMessage("Failed to deactivate the camera: \(detail)")
        }
        updateStatusBadge("Error", color: .systemRed)
    }
}

extension FourCharCode: ExpressibleByStringLiteral {
    
    public init(stringLiteral value: StringLiteralType) {
        var code: FourCharCode = 0
        // Value has to consist of 4 printable ASCII characters, e.g. '420v'.
        // Note: This implementation does not enforce printable range (32-126)
        if value.count == 4 && value.utf8.count == 4 {
            for byte in value.utf8 {
                code = code << 8 + FourCharCode(byte)
            }
        }
        else {
            print("FourCharCode: Can't initialize with '\(value)', only printable ASCII allowed. Setting to '????'.")
            code = 0x3F3F3F3F // = '????'
        }
        self = code
    }
    
    public init(extendedGraphemeClusterLiteral value: String) {
        self = FourCharCode(stringLiteral: value)
    }
    
    public init(unicodeScalarLiteral value: String) {
        self = FourCharCode(stringLiteral: value)
    }
    
    public init(_ value: String) {
        self = FourCharCode(stringLiteral: value)
    }
    
    public var string: String? {
        let cString: [CChar] = [
            CChar(self >> 24 & 0xFF),
            CChar(self >> 16 & 0xFF),
            CChar(self >> 8 & 0xFF),
            CChar(self & 0xFF),
            0
        ]
        return String(cString: cString)
    }
}

public extension CMIOObjectPropertyAddress {
    init(_ selector: CMIOObjectPropertySelector,
         _ scope: CMIOObjectPropertyScope = .anyScope,
         _ element: CMIOObjectPropertyElement = .anyElement) {
        self.init(mSelector: selector, mScope: scope, mElement: element)
    }
}

public extension CMIOObjectPropertyScope {
    /// The CMIOObjectPropertyScope for properties that apply to the object as a whole.
    /// All CMIOObjects have a global scope and for some it is their only scope.
    static let global = CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal)
    
    /// The wildcard value for CMIOObjectPropertyScopes.
    static let anyScope = CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard)
    
    /// The CMIOObjectPropertyScope for properties that apply to the input signal paths of the CMIODevice.
    static let deviceInput = CMIOObjectPropertyScope(kCMIODevicePropertyScopeInput)
    
    /// The CMIOObjectPropertyScope for properties that apply to the output signal paths of the CMIODevice.
    static let deviceOutput = CMIOObjectPropertyScope(kCMIODevicePropertyScopeOutput)
    
    /// The CMIOObjectPropertyScope for properties that apply to the play through signal paths of the CMIODevice.
    static let devicePlayThrough = CMIOObjectPropertyScope(kCMIODevicePropertyScopePlayThrough)
}

public extension CMIOObjectPropertyElement {
    /// The CMIOObjectPropertyElement value for properties that apply to the master element or to the entire scope.
    //static let master = CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster)
    static let main = CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
    /// The wildcard value for CMIOObjectPropertyElements.
    static let anyElement = CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
}
