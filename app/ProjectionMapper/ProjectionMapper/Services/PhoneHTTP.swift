import Foundation
import Network
import Security

struct PhoneRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data

    static let maximumBytes = 24 * 1024

    static func parse(_ data: Data) throws -> Self? {
        guard data.count <= maximumBytes else { throw PhoneError("Request is too large.") }
        guard let split = data.range(of: Data([13, 10, 13, 10])) else { return nil }
        guard let header = String(data: data[..<split.lowerBound], encoding: .utf8) else {
            throw PhoneError("Invalid request.")
        }
        let lines = header.components(separatedBy: "\r\n")
        let start = lines[0].split(separator: " ")
        guard start.count == 3, start[2] == "HTTP/1.1", ["GET", "POST"].contains(start[0]) else {
            throw PhoneError("Invalid request.")
        }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let fields = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { throw PhoneError("Invalid header.") }
            let key = fields[0].lowercased()
            guard headers[key] == nil else { throw PhoneError("Duplicate header.") }
            headers[key] = fields[1].trimmingCharacters(in: .whitespaces)
        }
        guard headers["transfer-encoding"] == nil,
              let size = Int(headers["content-length"] ?? "0"), size >= 0,
              size <= maximumBytes - split.upperBound else { throw PhoneError("Invalid body size.") }
        let body = data[split.upperBound...]
        if body.count < size { return nil }
        guard body.count == size else { throw PhoneError("Unexpected request data.") }
        return Self(method: String(start[0]), path: String(start[1]), headers: headers, body: Data(body))
    }
}

struct PhoneError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

struct PhoneResponse {
    var status: String
    var type = "application/json"
    var body: Data

    var bytes: Data {
        let headers = [
            "HTTP/1.1 \(status)", "Content-Type: \(type)", "Content-Length: \(body.count)", "Connection: close",
            "Cache-Control: no-store", "Referrer-Policy: no-referrer", "X-Content-Type-Options: nosniff",
            "Content-Security-Policy: default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src data:; frame-ancestors 'none'; base-uri 'none'"
        ].joined(separator: "\r\n")
        return Data((headers + "\r\n\r\n").utf8) + body
    }

    static func json(_ value: [String: Any], status: String = "200 OK") -> Self {
        Self(status: status, body: (try? JSONSerialization.data(withJSONObject: value)) ?? Data("{}".utf8))
    }
}

@MainActor
final class PhoneHTTPListener {
    private var listener: NWListener?
    private var clients: [UUID: NWConnection] = [:]
    var handle: ((PhoneRequest) -> PhoneResponse)?
    var stateChanged: ((NWListener.State) -> Void)?

    func start(address: String, port: UInt16, identityData: Data, password: String) throws {
        var items: CFArray?
        let result = SecPKCS12Import(identityData as CFData, [
            kSecImportExportPassphrase as String: password,
            kSecImportToMemoryOnly as String: true
        ] as CFDictionary, &items)
        guard result == errSecSuccess, let entries = items as? [[String: Any]],
              let item = entries.first, let rawIdentity = item[kSecImportItemIdentity as String],
              CFGetTypeID(rawIdentity as CFTypeRef) == SecIdentityGetTypeID(),
              let ip = IPv4Address(address), let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw PhoneError("Could not load the HTTPS identity or bind address.")
        }
        let imported = rawIdentity as! SecIdentity
        let identity: sec_identity_t?
        if let chain = item[kSecImportItemCertChain as String] as? [SecCertificate], chain.count > 1 {
            identity = sec_identity_create_with_certificates(imported, chain as CFArray)
        } else {
            identity = sec_identity_create(imported)
        }
        guard let identity else { throw PhoneError("Could not prepare the HTTPS identity.") }
        let tls = NWProtocolTLS.Options()
        sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions, .TLSv12)
        sec_protocol_options_set_local_identity(tls.securityProtocolOptions, identity)
        let parameters = NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
        try start(parameters: parameters, address: ip, port: endpointPort)
    }

    func startLocal(address: String, port: UInt16) throws {
        guard let ip = IPv4Address(address), let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw PhoneError("Choose an available local network address.")
        }
        try start(parameters: NWParameters(tls: nil, tcp: NWProtocolTCP.Options()), address: ip, port: endpointPort)
    }

    private func start(parameters: NWParameters, address: IPv4Address, port: NWEndpoint.Port) throws {
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(address), port: port)
        let next = try NWListener(using: parameters)
        listener = next
        next.newConnectionHandler = { [weak self] connection in
            MainActor.assumeIsolated { self?.accept(connection) }
        }
        next.stateUpdateHandler = { [weak self, weak next] state in
            MainActor.assumeIsolated {
                guard let self, self.listener === next else { return }
                self.stateChanged?(state)
            }
        }
        next.start(queue: .main)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for connection in clients.values { connection.cancel() }
        clients.removeAll()
    }

    private func accept(_ connection: NWConnection) {
        guard listener != nil, clients.count < 16 else { connection.cancel(); return }
        let id = UUID()
        clients[id] = connection
        connection.start(queue: .main)
        receive(id, accumulated: Data())
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.close(id) }
    }

    private func receive(_ id: UUID, accumulated: Data) {
        guard let connection = clients[id] else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, complete, error in
            MainActor.assumeIsolated {
                guard let self, self.clients[id] != nil else { return }
                let bytes = accumulated + (data ?? Data())
                do {
                    if let request = try PhoneRequest.parse(bytes), let response = self.handle?(request) {
                        connection.send(content: response.bytes, completion: .contentProcessed { [weak self] _ in
                            MainActor.assumeIsolated { self?.close(id) }
                        })
                    } else if complete || error != nil { self.close(id) }
                    else { self.receive(id, accumulated: bytes) }
                } catch {
                    self.close(id)
                }
            }
        }
    }

    private func close(_ id: UUID) { clients.removeValue(forKey: id)?.cancel() }
}
