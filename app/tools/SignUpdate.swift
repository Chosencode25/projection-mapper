import CryptoKit
import Darwin
import Foundation

// The release key is kept outside the repository and is never printed or passed as an argument.
let home = FileManager.default.homeDirectoryForCurrentUser
let directory = home.appendingPathComponent("Library/Application Support/ProjectionMapperReleaseSigning", isDirectory: true)
let keyFile = directory.appendingPathComponent("ed25519.key")
let files = FileManager.default

func privateKey(create: Bool) throws -> Curve25519.Signing.PrivateKey {
    if create {
        try files.createDirectory(at: directory, withIntermediateDirectories: true,
                                  attributes: [.posixPermissions: 0o700])
        let key = Curve25519.Signing.PrivateKey()
        let fd = Darwin.open(keyFile.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        if fd >= 0 {
            let output = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
            try output.write(contentsOf: key.rawRepresentation)
            try output.synchronize()
            try output.close()
        } else if errno != EEXIST {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }
    let fd = Darwin.open(keyFile.path, O_RDONLY | O_NOFOLLOW)
    guard fd >= 0 else { throw CocoaError(.fileNoSuchFile) }
    let input = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    var info = stat()
    guard fstat(fd, &info) == 0, info.st_uid == getuid(),
          info.st_mode & S_IFMT == S_IFREG, info.st_mode & 0o077 == 0, info.st_size == 32 else {
        throw CocoaError(.fileReadNoPermission)
    }
    return try Curve25519.Signing.PrivateKey(rawRepresentation: input.read(upToCount: 33) ?? Data())
}

do {
    switch Array(CommandLine.arguments.dropFirst()) {
    case ["setup"]:
        print(try privateKey(create: true).publicKey.rawRepresentation.base64EncodedString())
    case ["public-key"]:
        print(try privateKey(create: false).publicKey.rawRepresentation.base64EncodedString())
    case let args where args.count == 2 && args[0] == "sign":
        let zip = URL(fileURLWithPath: args[1])
        guard zip.pathExtension == "zip" else { throw CocoaError(.fileReadUnsupportedScheme) }
        let signature = try privateKey(create: false).signature(for: Data(contentsOf: zip, options: .mappedIfSafe))
        try signature.write(to: zip.appendingPathExtension("sig"), options: .withoutOverwriting)
        print(zip.lastPathComponent + ".sig")
    default:
        throw POSIXError(.EINVAL)
    }
} catch {
    fputs("Usage: swift app/tools/SignUpdate.swift setup | public-key | sign <archive.zip>\n\(error.localizedDescription)\n", stderr)
    exit(1)
}
