import Foundation
import Network

internal final class FrameDecoder {
    private let frameLength: Int
    private let maxPayloadLength: Int
    private var headerBuffer = Data()
    private var payloadBuffer = Data()
    private var payloadBytesRead = 0
    private var expectedPayloadLength: Int?
    private let onFrameStarted: () -> Void
    private let onFrameCompleted: (Int) -> Void
    private let onInvalidLength: (Int) -> Void

    init(
        frameLength: Int = 4,
        maxPayloadLength: Int = 65_536,
        onFrameStarted: @escaping () -> Void = {},
        onFrameCompleted: @escaping (Int) -> Void = { _ in },
        onInvalidLength: @escaping (Int) -> Void = { _ in }
    ) {
        self.frameLength = frameLength
        self.maxPayloadLength = maxPayloadLength
        self.onFrameStarted = onFrameStarted
        self.onFrameCompleted = onFrameCompleted
        self.onInvalidLength = onInvalidLength
    }

    func append(_ data: Data) -> [String] {
        var remaining = data
        var messages: [String] = []

        while !remaining.isEmpty {
            if let payloadLength = expectedPayloadLength {
                let bytesToRead = min(payloadLength - payloadBytesRead, remaining.count)
                payloadBuffer.append(Data(remaining.prefix(bytesToRead)))
                payloadBytesRead += bytesToRead
                remaining.removeFirst(bytesToRead)

                if payloadBytesRead == payloadLength {
                    if let message = String(data: payloadBuffer, encoding: .utf8) {
                        messages.append(message)
                    }
                    reset()
                    onFrameCompleted(payloadLength)
                }
            } else {
                if headerBuffer.isEmpty {
                    onFrameStarted()
                }
                let bytesToRead = min(frameLength - headerBuffer.count, remaining.count)
                headerBuffer.append(Data(remaining.prefix(bytesToRead)))
                remaining.removeFirst(bytesToRead)

                if headerBuffer.count == frameLength {
                    let payloadLength = readFrameLength()
                    if payloadLength <= 0 || payloadLength > maxPayloadLength {
                        onInvalidLength(payloadLength)
                        reset()
                        continue
                    }
                    expectedPayloadLength = payloadLength
                    payloadBuffer.removeAll(keepingCapacity: true)
                }
            }
        }

        return messages
    }

    func reset() {
        headerBuffer.removeAll(keepingCapacity: true)
        payloadBuffer.removeAll(keepingCapacity: true)
        payloadBytesRead = 0
        expectedPayloadLength = nil
    }

    private func readFrameLength() -> Int {
        return (Int(headerBuffer[0]) << 24)
            | (Int(headerBuffer[1]) << 16)
            | (Int(headerBuffer[2]) << 8)
            | Int(headerBuffer[3])
    }
}

class NetworkHandler: NetworkHostPlatform {
    private var listener: NWListener?
    private var connection: NWConnection?
    private var pendingConnection: NWConnection?
    private let queue = DispatchQueue(label: "com.soundmesh.network", qos: .userInitiated)
    private let frameLength = 4

    private var flutterApi: NetworkFlutterApi?
    private var binaryMessenger: FlutterBinaryMessenger?

    func setFlutterApi(_ api: NetworkFlutterApi) {
        self.flutterApi = api
    }

    func startHosting(port: Int64) throws -> Bool {
        stopAll()
        notifyState("connecting")

        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true

            let nwPort = NWEndpoint.Port(integerLiteral: UInt16(port))
            listener = try NWListener(using: parameters, on: nwPort)

            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.notifyState("connected")
                case .failed(let error):
                    print("Listener failed: \(error)")
                    self?.notifyState("failed")
                case .cancelled:
                    self?.notifyState("disconnected")
                default:
                    break
                }
            }

            listener?.newConnectionHandler = { [weak self] newConnection in
                if self?.connection == nil {
                    self?.pendingConnection = newConnection
                    self?.acceptConnection()
                } else {
                    newConnection.cancel()
                }
            }

            listener?.start(queue: queue)
            return true
        } catch {
            print("Failed to start hosting: \(error)")
            notifyState("failed")
            return false
        }
    }

    private func acceptConnection() {
        guard let conn = pendingConnection else { return }
        connection = conn
        pendingConnection = nil

        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.notifyState("connected")
                self?.startReading()
            case .failed(let error):
                print("Connection failed: \(error)")
                self?.notifyState("failed")
            case .cancelled:
                self?.notifyState("disconnected")
            default:
                break
            }
        }

        connection?.start(queue: queue)
    }

    func connectToHost(ipAddress: String, port: Int64) throws -> Bool {
        stopAll()
        notifyState("connecting")

        let host = NWEndpoint.Host(ipAddress)
        let nwPort = NWEndpoint.Port(integerLiteral: UInt16(port))

        connection = NWConnection(host: host, port: nwPort, using: .tcp)

        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.notifyState("connected")
                self?.startReading()
            case .failed(let error):
                print("Connection failed: \(error)")
                self?.notifyState("failed")
            case .cancelled:
                self?.notifyState("disconnected")
            default:
                break
            }
        }

        connection?.start(queue: queue)
        return true
    }

    func sendMessage(message: String) throws -> Bool {
        guard let conn = connection, conn.state == .ready else { return false }

        guard let data = message.data(using: .utf8) else { return false }

        var frame = Data()
        var length = UInt32(data.count).bigEndian
        frame.append(Data(bytes: &length, count: frameLength))
        frame.append(data)

        conn.send(content: frame, completion: .contentProcessed { error in
            if let error = error {
                print("Send error: \(error)")
            }
        })

        return true
    }

    func disconnect() throws {
        stopAll()
        notifyState("disconnected")
    }

    func getLocalIpAddress() throws -> String {
        var address = "127.0.0.1"

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return address
        }
        defer { freeifaddrs(ifaddr) }

        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    address = String(cString: hostname)
                }
            }
        }

        return address
    }

    private var frameDecoder: FrameDecoder?
    private var isReading = false
    private var readGeneration = 0

    private func startReading() {
        guard let conn = connection, conn.state == .ready, !isReading else { return }

        readGeneration += 1
        let generation = readGeneration
        frameDecoder = FrameDecoder(
            onFrameStarted: {
                print("NetworkHandler: Starting new frame read: headerBytesRead=0, payloadBytesRead=0")
            },
            onFrameCompleted: { payloadLength in
                print("NetworkHandler: Frame read complete: payloadLength=\(payloadLength), payloadBytesRead=0")
            },
            onInvalidLength: { frameLength in
                print("NetworkHandler: Invalid frame length: \(frameLength), resetting frame state")
            }
        )
        isReading = true
        readNextChunk(conn, generation: generation)
    }

    private func readNextChunk(_ conn: NWConnection, generation: Int) {
        guard isReading, readGeneration == generation, connection === conn, conn.state == .ready else {
            return
        }

        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] content, _, isComplete, error in
            guard let self = self,
                  self.isReading,
                  self.readGeneration == generation,
                  self.connection === conn else {
                return
            }

            var shouldContinue = true
            if let data = content, !data.isEmpty {
                let messages = self.frameDecoder?.append(data) ?? []
                for message in messages {
                    self.notifyMessage(message)
                }
            }

            if let error = error {
                print("NetworkHandler: Read error: \(error)")
                shouldContinue = false
            } else if isComplete {
                shouldContinue = false
            } else if content == nil || content?.isEmpty == true {
                print("NetworkHandler: Read returned no data before connection completion")
                shouldContinue = false
            }

            if shouldContinue {
                self.readNextChunk(conn, generation: generation)
            } else {
                self.finishReading(generation: generation)
                self.notifyState("disconnected")
            }
        }
    }

    private func finishReading(generation: Int) {
        guard readGeneration == generation else { return }
        isReading = false
        frameDecoder = nil
        print("NetworkHandler: Resetting frame state: headerBytesRead=0, payloadBytesRead=0")
    }

    private func stopAll() {
        listener?.cancel()
        listener = nil
        connection?.cancel()
        connection = nil
        pendingConnection?.cancel()
        pendingConnection = nil
    }

    private func notifyMessage(_ message: String) {
        guard let api = flutterApi else { return }
        // Pigeon FlutterApi calls reach Dart over the binary messenger and must
        // be invoked on the main thread. Network.framework handlers
        // (stateUpdateHandler, receive completion) run on our private queue,
        // so hop to main before calling into Flutter — same class of bug as
        // the Android @UiThread crash this mirrors.
        DispatchQueue.main.async {
            Task {
                do {
                    try await api.onMessageReceived(message: message)
                } catch {
                    print("Failed to notify message: \(error)")
                }
            }
        }
    }

    private func notifyState(_ state: String) {
        guard let api = flutterApi else { return }
        DispatchQueue.main.async {
            Task {
                do {
                    try await api.onConnectionStateChanged(state: state)
                } catch {
                    print("Failed to notify state: \(error)")
                }
            }
        }
    }
}
