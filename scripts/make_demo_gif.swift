import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers

// Renders an animated demo GIF of the NoDoze popover.
//
// NOTE: ImageRenderer cannot rasterize AppKit-backed controls (NSSwitch,
// NSTextField, NSButton) headlessly — they come out blank. So this DemoPopover
// mirrors Sources/PopoverContent.swift's exact layout/copy/colors using pure
// SwiftUI shapes (a drawn capsule switch + a drawn text field), which render
// cleanly. Keep it in sync with PopoverContent if the real UI changes.

struct DemoState {
    var isAwake: Bool
    var statusText: String
    var watchEnabled: Bool
    var watchRunning: Bool
    var pattern = "claude"
}

struct DemoSwitch: View {
    let on: Bool
    var body: some View {
        Capsule()
            .fill(on ? Color.orange : Color(white: 0.80))
            .frame(width: 38, height: 22)
            .overlay(
                Circle().fill(.white)
                    .padding(2)
                    .offset(x: on ? 8 : -8)
            )
    }
}

struct DemoRow: View {
    let title: String
    let subtitle: String
    let subtitleColor: Color
    let on: Bool
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(subtitleColor)
            }
            Spacer()
            DemoSwitch(on: on)
        }
    }
}

struct DemoPopover: View {
    let state: DemoState
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: state.isAwake ? "cup.and.saucer.fill" : "cup.and.saucer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(state.isAwake ? Color.orange : Color.secondary)
                Text("NoDoze").font(.headline)
                Spacer()
            }
            Divider()
            DemoRow(title: "Keep Mac Awake",
                    subtitle: state.statusText,
                    subtitleColor: .secondary,
                    on: state.isAwake)
            Divider()
            DemoRow(title: "Stay awake while a process runs",
                    subtitle: watchSubtitle(enabled: state.watchEnabled,
                                            running: state.watchRunning,
                                            pattern: state.pattern),
                    subtitleColor: state.watchEnabled && state.watchRunning ? .green : .secondary,
                    on: state.watchEnabled)
            if state.watchEnabled {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(white: 0.74))
                    .frame(height: 22)
                    .overlay(HStack {
                        Text(state.pattern).font(.callout)
                        Spacer()
                    }.padding(.horizontal, 7))
            }
            Divider()
            HStack {
                Image(systemName: "arrow.clockwise").foregroundStyle(.secondary)
                Spacer()
                Text("Quit").foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding(14)
        .frame(width: 268)
    }
}

func canvas(_ v: some View) -> some View {
    ZStack(alignment: .top) {
        LinearGradient(colors: [Color(red: 0.97, green: 0.98, blue: 1.0),
                                Color(red: 0.90, green: 0.92, blue: 0.96)],
                       startPoint: .top, endPoint: .bottom)
        v.background(Color(white: 0.99))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.black.opacity(0.12)))
            .padding(.top, 24)
    }
    .frame(width: 322, height: 330)
}

@MainActor
func renderCG(_ view: some View, scale: CGFloat) -> CGImage? {
    let renderer = ImageRenderer(content: view)
    renderer.scale = scale
    return renderer.cgImage
}

func writeGIF(_ frames: [(CGImage, Double)], to url: URL) -> Bool {
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else { return false }
    CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary as String:
        [kCGImagePropertyGIFLoopCount as String: 0]] as CFDictionary)
    for (img, delay) in frames {
        CGImageDestinationAddImage(dest, img, [kCGImagePropertyGIFDictionary as String:
            [kCGImagePropertyGIFDelayTime as String: delay]] as CFDictionary)
    }
    return CGImageDestinationFinalize(dest)
}

@main
struct DemoGif {
    @MainActor static func main() {
        let out = CommandLine.arguments.dropFirst().first ?? "demo.gif"
        let scale: CGFloat = 2

        let states: [(DemoState, Double)] = [
            (DemoState(isAwake: false, statusText: "Normal sleep",
                       watchEnabled: false, watchRunning: false), 1.7),
            (DemoState(isAwake: true, statusText: "Sleep off · lid-close safe",
                       watchEnabled: false, watchRunning: false), 1.9),
            (DemoState(isAwake: true, statusText: "Sleep off · lid-close safe",
                       watchEnabled: true, watchRunning: true), 2.4),
        ]

        var frames: [(CGImage, Double)] = []
        for (state, delay) in states {
            guard let cg = renderCG(canvas(DemoPopover(state: state)), scale: scale) else { continue }
            frames.append((cg, delay))
        }

        if writeGIF(frames, to: URL(fileURLWithPath: out)) {
            print("Wrote \(out) with \(frames.count) frames")
        } else {
            print("GIF write failed"); exit(1)
        }
    }
}
