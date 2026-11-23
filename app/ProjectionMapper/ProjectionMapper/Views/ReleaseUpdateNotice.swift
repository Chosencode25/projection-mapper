import AppKit
import SwiftUI

struct ReleaseUpdateNotice: View {
    let checker: ReleaseUpdateChecker
    let installedVersion: String
    let install: (ReleaseUpdate) -> Void
    let restart: () -> Void

    var body: some View {
        if let notice = checker.notice {
            VStack(alignment: .leading, spacing: 10) {
                switch notice {
                case .available(let update):
                    Label("Update Available", systemImage: "arrow.down.circle")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text("Installed \(installedVersion) · Available \(update.tag.dropFirst())")
                        .foregroundStyle(.secondary)
                    if checker.isPreparingInstall {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Downloading and verifying update…").foregroundStyle(.secondary)
                        }
                    } else {
                        if let error = checker.installError {
                            Text(error).foregroundStyle(.orange).font(.callout)
                        }
                        HStack {
                            Spacer()
                            Button("Later") { checker.dismiss() }
                            if checker.readyToInstall != nil {
                                Button("Restart to Install", action: restart).buttonStyle(.borderedProminent)
                            } else if update.archive != nil {
                                Button("Install Update") { install(update) }.buttonStyle(.borderedProminent)
                            } else {
                                Button("Download Update") {
                                    if NSWorkspace.shared.open(update.page) { checker.dismiss() }
                                }.buttonStyle(.borderedProminent)
                            }
                        }
                    }
                case .upToDate, .failed, .installationFailed:
                    HStack(alignment: .top, spacing: 12) {
                        switch notice {
                        case .upToDate: Text("Projection Mapper is up to date.")
                        case .installationFailed(let message): Text(message)
                        default: Text("Couldn’t check for updates. Try again later.")
                        }
                        Spacer(minLength: 0)
                        Button("Dismiss", systemImage: "xmark") { checker.dismiss() }
                            .labelStyle(.iconOnly).buttonStyle(.borderless)
                    }
                }
            }
            .padding(14)
            .frame(width: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.secondary.opacity(0.25)).allowsHitTesting(false) }
            .shadow(color: .black.opacity(0.22), radius: 7, y: 3)
            .padding(12)
            .accessibilityElement(children: .contain)
        }
    }
}
