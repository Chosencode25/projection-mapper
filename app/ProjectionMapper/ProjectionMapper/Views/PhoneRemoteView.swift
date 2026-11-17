import CoreImage.CIFilterBuiltins
import SwiftUI
import UniformTypeIdentifiers

struct PhoneRemoteView: View {
    @Bindable var remote: PhoneRemote
    @State private var hostname = ""
    @State private var address = ""
    @State private var identityURL: URL?
    @State private var password = ""
    @State private var importing = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Phone Remote").font(.headline)
            Text(remote.status).foregroundStyle(.secondary)
            if remote.isRunning {
                if let url = remote.pairingURL {
                    if let image = qrCode(url) {
                        Image(nsImage: image).interpolation(.none)
                            .resizable().scaledToFit().frame(width: 176, height: 176)
                            .padding(12).background(.white)
                            .accessibilityLabel("Phone pairing QR code")
                    }
                    Text(url.absoluteString).font(.caption.monospaced()).textSelection(.enabled)
                    Button("New Invitation") { remote.newInvitation() }
                }
                if remote.hasPendingPhone || remote.hasPhone {
                    Picker("Phone permissions", selection: $remote.role) {
                        ForEach(PhoneRole.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                if remote.hasPendingPhone {
                    Button("Approve Phone") { remote.approve() }.buttonStyle(.borderedProminent)
                }
                if remote.hasPhone { Text("Phone approved") }
                if remote.hasPendingPhone || remote.hasPhone {
                    Button("Revoke Phone") { remote.revoke(); remote.newInvitation() }
                }
                Button("Stop Phone Remote", role: .destructive) { remote.stop() }
            } else {
                TextField("HTTPS hostname", text: $hostname)
                TextField("Mac’s private IPv4 address", text: $address)
                Button(identityURL?.lastPathComponent ?? "Choose HTTPS Identity (.p12)…") { importing = true }
                SecureField("Identity password", text: $password)
                Button("Start Phone Remote") {
                    guard let identityURL else { return }
                    let scoped = identityURL.startAccessingSecurityScopedResource()
                    defer { if scoped { identityURL.stopAccessingSecurityScopedResource() } }
                    do {
                        let size = try identityURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                        guard (1...1_048_576).contains(size) else { throw PhoneError("Invalid identity file size.") }
                        try remote.start(hostname: hostname, address: address,
                                         identity: Data(contentsOf: identityURL), password: password)
                        error = nil
                        password = ""
                    } catch { self.error = error.localizedDescription }
                }.disabled(identityURL == nil || hostname.isEmpty || address.isEmpty)
                Text("Use a certificate your phone trusts for this hostname. The hostname must resolve to the Mac’s address on your network.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let error { Text(error).font(.caption).foregroundStyle(.orange) }
        }
        .textFieldStyle(.roundedBorder)
        .padding(16).frame(width: 360)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pkcs12]) { result in
            switch result {
            case .success(let url): identityURL = url; error = nil
            case .failure(let failure): error = failure.localizedDescription
            }
        }
    }

    private func qrCode(_ url: URL) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        guard let image = filter.outputImage else { return nil }
        let scaled = image.transformed(by: CGAffineTransform(scaleX: 5, y: 5))
        guard let result = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: result, size: scaled.extent.size)
    }
}
