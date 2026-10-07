import SwiftUI

struct CalibrationControls: View {
    let session: EditorSession
    @State private var statusClockActive = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CALIBRATION").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Picker("Pattern", selection: Binding(get: { session.calibration.pattern }, set: { session.setCalibrationPattern($0) })) {
                ForEach(CalibrationPattern.allCases) { Text($0.title).tag($0) }
            }.accessibilityLabel("Temporary calibration pattern")
            if session.calibration.pattern.usesCellCounts {
                Stepper("Columns: \(session.calibration.columns)", value: Binding(get: { session.calibration.columns }, set: { session.setCalibrationColumns($0) }), in: 2...64)
                Stepper("Rows: \(session.calibration.rows)", value: Binding(get: { session.calibration.rows }, set: { session.setCalibrationRows($0) }), in: 2...64)
            }
            if session.calibration.pattern.usesLineWidth {
                HStack {
                    Text("Line width")
                    Spacer()
                    Text("\(session.calibration.lineWidth.formatted(.number.precision(.fractionLength(0...1)))) px").monospacedDigit()
                }.font(.caption)
                Slider(value: Binding(get: { Double(session.calibration.lineWidth) }, set: { session.setCalibrationLineWidth(Float($0)) }), in: 1...4, step: 0.5)
                    .accessibilityLabel("Calibration line width in drawable pixels")
            }
            if session.calibration.pattern.isActive {
                Button("Return to Normal Content") { session.setCalibrationPattern(.normal) }
            }
            TimelineView(.animation(minimumInterval: 0.1, paused: !statusClockActive)) { _ in
                let uptime = ProcessInfo.processInfo.systemUptime
                let fading = session.showOutput.isFading(at: uptime)
                Text(session.calibrationStatus(at: uptime))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    .onChange(of: fading) { _, value in statusClockActive = value }
            }
            .onChange(of: session.showOutput, initial: true) { _, value in
                statusClockActive = value.isFading(at: ProcessInfo.processInfo.systemUptime)
            }
            Text("Temporary patterns cover visible mapped faces and bypass content opacity, brightness, crop and flips. Face masks, master brightness, fades and blackout still apply. Normal Content returns to current content; Restore keeps the selected pattern.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct CalibrationPatternMenu: View {
    let session: EditorSession
    var body: some View {
        ForEach(CalibrationPattern.allCases) { pattern in
            Button { session.setCalibrationPattern(pattern) } label: {
                if session.calibration.pattern == pattern { Label(pattern.title, systemImage: "checkmark") }
                else { Text(pattern.title) }
            }
        }
    }
}
