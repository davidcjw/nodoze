import SwiftUI

/// Pure, value-driven popover UI. No model, no side effects — so it can be
/// rendered headlessly (e.g. for the demo GIF) and previewed in any state.
struct PopoverContent: View {
    let isAwake: Bool
    let statusText: String
    let needsSetup: Bool
    let busy: Bool
    let watchEnabled: Bool
    let watchRunning: Bool
    @Binding var watchPattern: String

    var onToggleAwake: () -> Void = {}
    var onToggleWatch: (Bool) -> Void = { _ in }
    var onRefresh: () -> Void = {}
    var onQuit: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: isAwake ? "cup.and.saucer.fill" : "cup.and.saucer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isAwake ? Color.orange : Color.secondary)
                Text("NoDoze").font(.headline)
                Spacer()
            }

            Divider()

            Toggle(isOn: Binding(get: { isAwake }, set: { _ in onToggleAwake() })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep Mac Awake").font(.callout.weight(.medium))
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(needsSetup ? Color.orange : Color.secondary)
                }
            }
            .toggleStyle(.switch)
            .tint(.orange)
            .disabled(busy)

            if needsSetup {
                Text("Permission needed — flip the toggle again and approve the prompt.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Toggle(isOn: Binding(get: { watchEnabled }, set: { onToggleWatch($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stay awake while a process runs").font(.callout.weight(.medium))
                    Text(watchSubtitle(enabled: watchEnabled, running: watchRunning, pattern: watchPattern))
                        .font(.caption)
                        .foregroundStyle(watchEnabled && watchRunning ? Color.green : Color.secondary)
                }
            }
            .toggleStyle(.switch)
            .tint(.orange)

            if watchEnabled {
                TextField("process name", text: $watchPattern)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
            }

            Divider()

            HStack {
                Button { onRefresh() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                    .help("Refresh state")
                Spacer()
                Button("Quit") { onQuit() }
                    .buttonStyle(.borderless)
            }
            .font(.caption)
        }
        .padding(14)
        .frame(width: 268)
    }
}
