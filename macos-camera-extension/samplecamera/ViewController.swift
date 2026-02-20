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
    private var qrExpiryTimer: Timer?
    private var qrAutoRefreshTimer: Timer?
    private var hostBridgeIsRunning = false
    private var hostBridgeAutoStartAttempted = false
    private var latestHostResourceStatus: HostResourceStatus?
    private var latestQrPayloadText: String?
    private var latestQrExpiryDate: Date?
    private var qrTokenRequestInFlight = false
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

    private struct HostResourceStatus {
        var paired: Bool
        var hostStatus: String
        var phoneName: String?
        var phoneId: String?
        var camera: Bool
        var microphone: Bool
        var speaker: Bool
        var cameraLens: String
        var cameraOrientationMode: String
        var cameraAvailable: Bool
        var microphoneAvailable: Bool
        var speakerAvailable: Bool
        var cameraStreamUrl: String?
        var issues: [String]
    }
    
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
        qrExpiryTimer?.invalidate()
        qrAutoRefreshTimer?.invalidate()
    }


}

private extension ViewController {
    static let logTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    static let qrISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let qrISO8601FallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    var hostBridgeBaseURL: URL {
        URL(string: "http://127.0.0.1:8787")!
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
        var request = URLRequest(url: hostBridgeBaseURL.appendingPathComponent("health"))
        request.timeoutInterval = 1.2
        URLSession.shared.dataTask(with: request) { _, response, error in
            guard error == nil,
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                completion(false)
                return
            }
            completion(true)
        }.resume()
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
                        self.requestQrToken(manual: false)
                    }
                    if transitioned {
                        self.showMessage("host bridge online at \(self.hostBridgeBaseURL.absoluteString)")
                    }
                } else {
                    self.updateHostBridgeBadge("Offline", color: .systemOrange)
                    self.hostBridgeDetailLabel.stringValue = "Host bridge is not running. Android cannot pair/discover until started."
                    self.hostBridgeStartButton.title = "Start Host Bridge"
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

    private func clearQrTimers() {
        qrExpiryTimer?.invalidate()
        qrExpiryTimer = nil
        qrAutoRefreshTimer?.invalidate()
        qrAutoRefreshTimer = nil
    }

    private func parseQrExpiryDate(_ rawValue: String?) -> Date? {
        guard let raw = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if let parsed = Self.qrISO8601Formatter.date(from: raw) {
            return parsed
        }
        return Self.qrISO8601FallbackFormatter.date(from: raw)
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

    private func formatQrRemaining(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        let minutes = total / 60
        let seconds = total % 60
        return "\(minutes)m \(seconds)s"
    }

    @objc private func refreshQrExpiryLabelTick() {
        guard let expiryDate = latestQrExpiryDate else {
            qrExpiryLabel.stringValue = "Expiry: unknown"
            return
        }

        let remaining = expiryDate.timeIntervalSinceNow
        if remaining <= 0 {
            qrExpiryLabel.stringValue = "Expiry: expired (refreshing)"
            if hostBridgeIsRunning, !qrTokenRequestInFlight {
                requestQrToken(manual: false)
            }
            return
        }
        qrExpiryLabel.stringValue = "Expiry: in \(formatQrRemaining(remaining))"
    }

    private func scheduleQrAutoRefresh() {
        qrAutoRefreshTimer?.invalidate()
        guard let expiryDate = latestQrExpiryDate else { return }
        let refreshInterval = max(1.0, expiryDate.timeIntervalSinceNow - 5.0)
        qrAutoRefreshTimer = Timer.scheduledTimer(
            timeInterval: refreshInterval,
            target: self,
            selector: #selector(autoRefreshQrToken),
            userInfo: nil,
            repeats: false
        )
    }

    private func applyQrToken(_ qrToken: [String: Any], manual: Bool) {
        let payloadText = (qrToken["payloadText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        latestQrPayloadText = (payloadText?.isEmpty == false) ? payloadText : nil
        latestQrExpiryDate = parseQrExpiryDate(qrToken["expiresAt"] as? String)

        if let image = imageFromQrDataUrl(qrToken["qrImageDataUrl"] as? String) {
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
        clearQrTimers()
        refreshQrExpiryLabelTick()
        qrExpiryTimer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(refreshQrExpiryLabelTick),
            userInfo: nil,
            repeats: true
        )
        scheduleQrAutoRefresh()

        let token = (qrToken["token"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let tokenPreview = token.isEmpty ? "n/a" : "\(token.prefix(6))…"
        let expiryText = (qrToken["expiresAt"] as? String) ?? "unknown"
        showMessage("qr token ready token=\(tokenPreview) expires=\(expiryText)")
    }

    private func requestQrToken(manual: Bool) {
        guard hostBridgeIsRunning else {
            resetQrSection(bridgeOnline: false)
            return
        }
        if qrTokenRequestInFlight {
            return
        }
        qrTokenRequestInFlight = true
        qrStatusLabel.stringValue = manual ? "Regenerating QR token…" : "Generating QR token…"
        qrRegenerateButton.isEnabled = false

        var request = URLRequest(url: hostBridgeBaseURL.appendingPathComponent("api/bootstrap/qr-token"))
        request.httpMethod = "POST"
        request.timeoutInterval = 2.0
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.qrTokenRequestInFlight = false
                self.qrRegenerateButton.isEnabled = self.hostBridgeIsRunning
                if let error = error {
                    self.qrStatusLabel.stringValue = "Failed to generate QR token."
                    self.qrExpiryLabel.stringValue = "Check host bridge logs and retry."
                    self.showMessage("qr token request failed: \(error.localizedDescription)")
                    return
                }
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    self.qrStatusLabel.stringValue = "Failed to generate QR token (HTTP \(http.statusCode))."
                    self.qrExpiryLabel.stringValue = "Check host bridge status and retry."
                    self.showMessage("qr token request returned HTTP \(http.statusCode)")
                    return
                }
                guard
                    let data = data,
                    let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let qrToken = root["qrToken"] as? [String: Any]
                else {
                    self.qrStatusLabel.stringValue = "QR token response malformed."
                    self.qrExpiryLabel.stringValue = "Try regenerating QR."
                    self.showMessage("qr token request returned invalid payload")
                    return
                }
                self.applyQrToken(qrToken, manual: manual)
            }
        }.resume()
    }

    @objc func regenerateQrToken(_ sender: Any?) {
        requestQrToken(manual: true)
    }

    @objc func autoRefreshQrToken() {
        requestQrToken(manual: false)
    }

    @objc func copyQrPayload(_ sender: Any?) {
        guard let payloadText = latestQrPayloadText else {
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
        clearQrTimers()
        latestQrPayloadText = nil
        latestQrExpiryDate = nil
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
        var request = URLRequest(url: hostBridgeBaseURL.appendingPathComponent("api/status"))
        request.timeoutInterval = 1.5
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard error == nil, let data = data else {
                completion(nil)
                return
            }
            guard
                let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let status = root["status"] as? [String: Any]
            else {
                completion(nil)
                return
            }

            let paired = status["paired"] as? Bool ?? false
            let hostStatus = status["hostStatus"] as? String ?? (paired ? "Paired" : "Not Paired")
            let phone = status["phone"] as? [String: Any]
            let resources = status["resources"] as? [String: Any]
            let capabilities = status["capabilities"] as? [String: Any]
            let phoneCamera = status["phoneCamera"] as? [String: Any]
            let camera = resources?["camera"] as? Bool ?? false
            let microphone = resources?["microphone"] as? Bool ?? false
            let speaker = resources?["speaker"] as? Bool ?? false
            let cameraLens = ((phoneCamera?["lens"] as? String) ?? "back")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let cameraOrientationMode = ((phoneCamera?["orientationMode"] as? String) ?? "auto")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let cameraAvailable = capabilities?["camera"] as? Bool ?? true
            let microphoneAvailable = capabilities?["microphone"] as? Bool ?? true
            let speakerAvailable = capabilities?["speaker"] as? Bool ?? true
            let streamUrl = status["cameraStreamUrl"] as? String
            let issues = (status["issues"] as? [[String: Any]] ?? []).compactMap { issue in
                let resource = issue["resource"] as? String ?? "resource"
                let message = issue["message"] as? String ?? "unknown issue"
                return "\(resource): \(message)"
            }

            completion(
                HostResourceStatus(
                    paired: paired,
                    hostStatus: hostStatus,
                    phoneName: phone?["deviceName"] as? String,
                    phoneId: phone?["deviceId"] as? String,
                    camera: camera,
                    microphone: microphone,
                    speaker: speaker,
                    cameraLens: cameraLens,
                    cameraOrientationMode: cameraOrientationMode,
                    cameraAvailable: cameraAvailable,
                    microphoneAvailable: microphoneAvailable,
                    speakerAvailable: speakerAvailable,
                    cameraStreamUrl: streamUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
                    issues: issues
                )
            )
        }.resume()
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

        hostBridgeBadge = NSTextField(labelWithString: "Offline")
        hostBridgeBadge.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        hostBridgeBadge.alignment = .center
        hostBridgeBadge.wantsLayer = true
        hostBridgeBadge.layer?.cornerRadius = 8
        hostBridgeBadge.layer?.masksToBounds = true
        hostBridgeBadge.backgroundColor = .clear
        hostBridgeBadge.drawsBackground = true

        hostBridgeDetailLabel = NSTextField(labelWithString: "Checking host bridge service status...")
        hostBridgeDetailLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        hostBridgeDetailLabel.textColor = .secondaryLabelColor
        hostBridgeDetailLabel.lineBreakMode = .byWordWrapping
        hostBridgeDetailLabel.maximumNumberOfLines = 2

        let hostControlsRow = NSStackView()
        hostControlsRow.orientation = .horizontal
        hostControlsRow.distribution = .fillProportionally
        hostControlsRow.spacing = 10

        hostBridgeStartButton = NSButton(title: "Start Host Bridge", target: self, action: #selector(startHostBridge(_:)))
        hostBridgeStartButton.bezelStyle = .rounded
        hostBridgeStartButton.controlSize = .large

        hostBridgeOpenButton = NSButton(title: "Open Host UI", target: self, action: #selector(openHostBridgeUI(_:)))
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

        qrImageView = NSImageView()
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

        qrStatusLabel = NSTextField(labelWithString: "Checking host bridge...")
        qrStatusLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        qrStatusLabel.textColor = .secondaryLabelColor
        qrStatusLabel.lineBreakMode = .byWordWrapping
        qrStatusLabel.maximumNumberOfLines = 2

        qrExpiryLabel = NSTextField(labelWithString: "Expiry: unknown")
        qrExpiryLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        qrExpiryLabel.textColor = .secondaryLabelColor

        let qrButtonsRow = NSStackView()
        qrButtonsRow.orientation = .horizontal
        qrButtonsRow.spacing = 8

        qrRegenerateButton = NSButton(title: "Regenerate QR", target: self, action: #selector(regenerateQrToken(_:)))
        qrRegenerateButton.bezelStyle = .rounded
        qrRegenerateButton.controlSize = .regular

        qrCopyPayloadButton = NSButton(title: "Copy Payload", target: self, action: #selector(copyQrPayload(_:)))
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

        resourceStatusBadge = NSTextField(labelWithString: "Unavailable")
        resourceStatusBadge.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        resourceStatusBadge.alignment = .center
        resourceStatusBadge.wantsLayer = true
        resourceStatusBadge.layer?.cornerRadius = 8
        resourceStatusBadge.layer?.masksToBounds = true
        resourceStatusBadge.backgroundColor = .clear
        resourceStatusBadge.drawsBackground = true

        phoneIdentityLabel = NSTextField(labelWithString: "Phone: unknown")
        phoneIdentityLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        phoneIdentityLabel.textColor = .secondaryLabelColor
        phoneIdentityLabel.lineBreakMode = .byTruncatingMiddle

        resourceIssuesLabel = NSTextField(labelWithString: "Issues: n/a")
        resourceIssuesLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        resourceIssuesLabel.textColor = .secondaryLabelColor
        resourceIssuesLabel.lineBreakMode = .byWordWrapping
        resourceIssuesLabel.maximumNumberOfLines = 2

        func makeResourceRow(_ name: String) -> (NSStackView, NSTextField) {
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

        let (cameraRow, cameraChip) = makeResourceRow("Camera")
        cameraStatusChip = cameraChip
        let (microphoneRow, microphoneChip) = makeResourceRow("Microphone")
        microphoneStatusChip = microphoneChip
        let (speakerRow, speakerChip) = makeResourceRow("Speaker")
        speakerStatusChip = speakerChip

        func makeMetadataRow(_ name: String, initialValue: String) -> (NSStackView, NSTextField) {
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

        let (lensRow, lensValue) = makeMetadataRow("Camera Lens", initialValue: "Unknown")
        cameraLensValueLabel = lensValue
        let (orientationRow, orientationValue) = makeMetadataRow("Orientation", initialValue: "Unknown")
        cameraOrientationValueLabel = orientationValue

        let resourceControlsRow = NSStackView()
        resourceControlsRow.orientation = .horizontal
        resourceControlsRow.distribution = .fillProportionally
        resourceControlsRow.spacing = 10
        syncResourceButton = NSButton(title: "Refresh Status", target: self, action: #selector(syncHostResourceStatus(_:)))
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
        updateHostBridgeBadge("Offline", color: .systemOrange)
        resetQrSection(bridgeOnline: false)
        resetHostResourceSection(bridgeOnline: false)

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

        statusBadge = NSTextField(labelWithString: "Idle")
        statusBadge.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        statusBadge.alignment = .center
        statusBadge.wantsLayer = true
        statusBadge.layer?.cornerRadius = 8
        statusBadge.layer?.masksToBounds = true
        statusBadge.backgroundColor = NSColor.clear
        statusBadge.drawsBackground = true

        statusDetailLabel = NSTextField(labelWithString: "Preparing frame server and extension environment…")
        statusDetailLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        statusDetailLabel.textColor = .secondaryLabelColor
        statusDetailLabel.lineBreakMode = .byWordWrapping
        statusDetailLabel.maximumNumberOfLines = 2

        streamDemandLabel = NSTextField(labelWithString: "Capture demand: unknown")
        streamDemandLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        streamDemandLabel.textColor = .secondaryLabelColor

        let controlsRow = NSStackView()
        controlsRow.orientation = .horizontal
        controlsRow.distribution = .fillProportionally
        controlsRow.spacing = 10

        let enableButton = NSButton(title: "Enable Extension", target: self, action: #selector(activate(_:)))
        enableButton.bezelStyle = .rounded
        enableButton.controlSize = .large

        let disableButton = NSButton(title: "Disable Extension", target: self, action: #selector(deactivate(_:)))
        disableButton.bezelStyle = .rounded
        disableButton.controlSize = .large

        let settingsButton = NSButton(title: "Open Settings", target: self, action: #selector(openExtensionsSettings(_:)))
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

        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearLog(_:)))
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
        self.logTextView = textView

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
