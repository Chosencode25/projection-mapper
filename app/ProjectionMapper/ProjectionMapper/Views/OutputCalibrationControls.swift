import SwiftUI

struct OutputCalibrationControls: View {
    let session: EditorSession
    @State private var draft: OutputCalibrationProfile?
    @State private var savedNotice: String?
    var body: some View {
        DisclosureGroup("Output Calibration") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Diagnostic", selection: Binding(get: { session.projectorOutput.diagnostic }, set: { session.projectorOutput.setDiagnostic($0) })) {
                    ForEach(OutputDiagnostic.allCases) { mode in Text(mode.rawValue).tag(mode) }
                }.disabled(!session.projectorOutput.isOpen)
                if session.projectorOutput.diagnostic != .normal {
                    Button("Finish Output Calibration") { session.projectorOutput.setDiagnostic(.normal) }
                    Text(session.projectorOutput.cadence.summary).font(.caption).textSelection(.enabled)
                }
                Text("Boundary/flash fixtures cover the whole output. Submission cadence does not measure optical projector delay. Blackout overrides fixtures.").font(.caption).foregroundStyle(.secondary)
                if draft != nil {
                    TextField("Measured delay (ms)", value: Binding(get: { draft?.measuredDelayMilliseconds ?? 0 }, set: { draft?.measuredDelayMilliseconds = $0; savedNotice = nil }), format: .number)
                    TextField("Future compensation (ms)", value: Binding(get: { draft?.compensationMilliseconds ?? 0 }, set: { draft?.compensationMilliseconds = $0; savedNotice = nil }), format: .number)
                    TextField("Measurement notes / equipment", text: Binding(get: { draft?.notes ?? "" }, set: { draft?.notes = String($0.prefix(2000)); savedNotice = nil }), axis: .vertical).lineLimit(2...5)
                    Text("Delay: 0–2000 ms. Compensation: −500…+500 ms, reserved for v2.02; it does not alter playback yet. Positive will evaluate visuals later to compensate a late image.").font(.caption).foregroundStyle(.secondary)
                    if let profile = session.output.calibrationProfile, let display = session.output.selectedDisplay, !profile.matches(display) {
                        Text("Display mode differs from the saved profile. Remeasure before saving this mode.").font(.caption).foregroundStyle(.orange)
                    }
                    Button("Save Device Calibration") {
                        guard let draft, draft.isValid else { return }
                        session.output.saveCalibration(draft); savedNotice = "Saved on this Mac for this device and mode."
                    }.disabled(draft?.isValid != true)
                    if let savedNotice { Text(savedNotice).font(.caption).foregroundStyle(.secondary) }
                } else {
                    Text("Calibration profiles require a unique device identity and valid display mode.").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(.top, 8)
        }
        .onAppear { reload() }
        .onChange(of: session.output.selectedDisplay) { _, _ in reload() }
    }
    private func reload() {
        savedNotice = nil
        guard let display = session.output.selectedDisplay, let uuid = display.uuid,
              session.output.displays.filter({ $0.uuid == uuid }).count == 1 else { draft = nil; return }
        let saved = session.output.calibrationProfile
        draft = saved?.matches(display) == true ? saved : OutputCalibrationProfile(display: display)
    }
}
