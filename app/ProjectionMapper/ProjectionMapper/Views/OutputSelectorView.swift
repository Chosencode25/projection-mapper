import SwiftUI

struct OutputSelectorView: View {
    let output: OutputSelectionState
    var compact = false

    var body: some View {
        Menu {
            choice("Test Window", destination: .testWindow)
            ForEach(output.displays) { display in
                choice(output.menuName(for: display) + (display.unavailableReason.map { " — \($0)" } ?? ""),
                       destination: .display(display.id))
                    .disabled(!display.isEligible)
            }
        } label: {
            Text(output.selectedName).lineLimit(1).truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
        .frame(maxWidth: compact ? 190 : .infinity)
        .help("Output: \(output.selectedName). Select Test Window or one independent external display; output opens explicitly.")
        .accessibilityLabel("Output destination")
        .accessibilityValue(output.selectedName)
    }

    private func choice(_ title: String, destination: OutputDestination) -> some View {
        Button { output.select(destination) } label: {
            if output.destination == destination {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }
}
