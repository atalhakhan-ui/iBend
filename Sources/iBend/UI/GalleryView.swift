import SwiftUI
import AppKit

enum Slot: String, CaseIterable, Identifiable {
    case opening, closing
    var id: String { rawValue }
    var label: String { self == .opening ? "Lid opens" : "Lid closes" }
}

struct GalleryView: View {
    @ObservedObject private var settings = Settings.shared
    @State private var slot: Slot = .opening

    private let columns = [GridItem(.adaptive(minimum: 230, maximum: 320), spacing: 16)]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    randomCard
                    ForEach(TransitionLibrary.all, id: \.id) { transition in
                        card(for: transition)
                    }
                }
                .padding(16)
            }
        }
        .frame(minWidth: 760, minHeight: 540)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Picker("", selection: $slot) {
                    ForEach(Slot.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 230)

                Text("Choose what plays when the \(slot == .opening ? "lid opens" : "lid closes").")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Preview full screen") {
                    TransitionController.shared.previewRoundTrip(
                        TransitionLibrary.transition(for: settings.closingID),
                        TransitionLibrary.transition(for: settings.openingID)
                    )
                }
            }

            HStack(spacing: 18) {
                Picker("Palette", selection: $settings.paletteID) {
                    ForEach(Palette.all) { p in
                        HStack { swatch(p); Text(p.name) }.tag(p.id)
                    }
                }
                .frame(width: 230)

                HStack(spacing: 8) {
                    Text("Speed").foregroundStyle(.secondary)
                    Slider(value: $settings.speed, in: 0.5...2.0)
                        .frame(width: 160)
                    Text(String(format: "%.2f×", settings.speed))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .leading)
                }

                Toggle("Enabled", isOn: $settings.enabled)

                Spacer()
            }
        }
        .padding(16)
    }

    private func swatch(_ p: Palette) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(p.nsColors.enumerated()), id: \.offset) { _, c in
                Rectangle().fill(Color(nsColor: c)).frame(width: 8, height: 12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    // MARK: Cards

    private var selectedID: String {
        slot == .opening ? settings.openingID : settings.closingID
    }

    private func select(_ id: String) {
        if slot == .opening { settings.openingID = id } else { settings.closingID = id }
    }

    private func card(for transition: Transition) -> some View {
        let isSelected = selectedID == transition.id
        return VStack(alignment: .leading, spacing: 0) {
            TransitionPreview(transition: transition,
                              palette: settings.palette,
                              duration: min(1.2, settings.duration(for: transition)))
                .frame(height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(8)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(transition.title).font(.headline)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                    }
                }
                Text(transition.blurb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isSelected ? Color.accentColor : Color.black.opacity(0.12),
                              lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture { select(transition.id) }
    }

    private var randomCard: some View {
        let isSelected = selectedID == TransitionLibrary.randomID
        return VStack(alignment: .leading, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: settings.palette.nsColors.map { Color(nsColor: $0) },
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "shuffle")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(radius: 6)
            }
            .frame(height: 132)
            .padding(8)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Random").font(.headline)
                    Spacer()
                    if isSelected { Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint) }
                }
                Text("Pick a different transition every time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isSelected ? Color.accentColor : Color.black.opacity(0.12),
                              lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture { select(TransitionLibrary.randomID) }
    }
}

@MainActor
final class GalleryWindowController {
    static let shared = GalleryWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false
            )
            w.title = "iBend Transitions"
            w.contentViewController = NSHostingController(rootView: GalleryView())
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
