import Foundation
import Network

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

    private func startReading() {
        readNextFrame()
    }

    private func readNextFrame() {
        guard let conn = connection, conn.state == .ready else { return }

        conn.receive(minimumIncompleteLength: 1, maximumLength: frameLength) { [weak self] content, _, isComplete, error in
            if let error = error {
                print("Read error: \(error)")
                return
            }

            if isComplete {
                self?.notifyState("disconnected")
                return
            }

            guard let lengthData = content, lengthData.count == self?.frameLength else {
                self?.readNextFrame()
                return
            }

            let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

            if length == 0 || length > 65536 {
                print("Invalid frame length: \(length)")
                self?.readNextFrame()
                return
            }

            self?.readPayload(length: Int(length))
        }
    }

    private func readPayload(length: Int) {
        guard let conn = connection, conn.state == .ready else { return }

        conn.receive(minimumIncompleteLength: length, maximumLength: length) { [weak self] content, _, isComplete, error in
            if let error = error {
                print("Read payload error: \(error)")
                return
            }

            if isComplete {
                self?.notifyState("disconnected")
                return
            }

            if let data = content, let message = String(data: data, encoding: .utf8) {
                self?.notifyMessage(message)
            }

            self?.readNextFrame()
        }
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
