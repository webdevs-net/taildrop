// TailDrop — drag files in, get tailnet links out.
//
// The window is a drop target. Each drop shells out to `tnshare`, which does the
// real work (clone or upload, mint a token, publish over Tailscale Serve) and the
// resulting link is copied to the clipboard. The stack below lists live shares
// with the time left, and can copy or revoke each one.

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Model

struct Share: Identifiable, Decodable, Equatable {
    let token: String
    let name: String
    let url: String
    let kind: String      // "local" | "hosted"
    let host: String
    let expires: Double   // unix seconds, 0 = never

    var id: String { token }
    var isHosted: Bool { kind == "hosted" }

    func timeLeft(now: Date = Date()) -> String {
        guard expires > 0 else { return "no expiry" }
        let remaining = expires - now.timeIntervalSince1970
        if remaining <= 0 { return "expired" }
        let minutes = Int(remaining) / 60
        if minutes < 60 { return "\(minutes)m left" }
        return "\(minutes / 60)h \(minutes % 60)m left"
    }
}

enum Destination: String, CaseIterable, Identifiable {
    case local, hosted
    var id: String { rawValue }

    var label: String { self == .local ? "This Mac" : "ovh1" }
    var blurb: String {
        self == .local
            ? "Served from this Mac. No upload, but it dies on sleep and only your own devices may connect — run tnshare doctor."
            : "Uploaded to ovh1 and served from there. Survives sleep, and reaches people your Mac's ACL blocks."
    }
}

// MARK: - tnshare bridge

enum Tnshare {
    static let binary = NSString(string: "~/Library/Application Support/TailnetShare/bin/tnshare")
        .expandingTildeInPath

    @discardableResult
    static func run(_ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = args
        // Finder/launchd gives the app a minimal PATH; tnshare needs ssh and scp.
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
        process.environment = env

        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()

        let data = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let stdout = String(data: data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            let message = String(data: errData, encoding: .utf8) ?? "tnshare failed"
            throw NSError(domain: "tnshare", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey:
                                        message.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
        return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func list() -> [Share] {
        guard let json = try? run(["list", "--json"]),
              let data = json.data(using: .utf8),
              let shares = try? JSONDecoder().decode([Share].self, from: data)
        else { return [] }
        return shares
    }

    static func add(paths: [String], to destination: Destination) throws -> [String] {
        let args = destination == .hosted ? ["hosted"] + paths : ["add"] + paths
        let output = try run(args)
        return output.split(separator: "\n")
            .map(String.init)
            .filter { $0.hasPrefix("https://") }
    }

    static func stop(token: String) throws { try run(["stop", token]) }
}

// MARK: - Store

@MainActor
final class Store: ObservableObject {
    @Published var shares: [Share] = []
    @Published var destination: Destination = .local {
        didSet { UserDefaults.standard.set(destination.rawValue, forKey: "destination") }
    }
    @Published var status: String = ""
    @Published var busy = false
    @Published var tick = Date()
    @Published var storage = ""

    private var timer: Timer?

    init() {
        if let saved = UserDefaults.standard.string(forKey: "destination"),
           let value = Destination(rawValue: saved) {
            destination = value
        }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick = Date()
                self?.refresh()
            }
        }
    }

    func refresh() {
        Task.detached(priority: .utility) {
            let shares = Tnshare.list()
            let usage = (try? Tnshare.run(["du"])) ?? ""
            await MainActor.run {
                self.shares = shares
                self.storage = usage
            }
        }
    }

    func share(paths: [String]) {
        guard !paths.isEmpty else { return }
        busy = true
        let destination = self.destination
        let noun = paths.count == 1 ? (paths[0] as NSString).lastPathComponent : "\(paths.count) items"
        status = destination == .hosted ? "Uploading \(noun) to ovh1…" : "Sharing \(noun)…"

        Task.detached(priority: .userInitiated) {
            do {
                let urls = try Tnshare.add(paths: paths, to: destination)
                await MainActor.run {
                    self.busy = false
                    if urls.isEmpty {
                        self.status = "No link came back."
                    } else {
                        self.copy(urls.joined(separator: "\n"))
                        self.status = urls.count == 1
                            ? "Link copied — \(noun)"
                            : "\(urls.count) links copied"
                        NSSound(named: "Glass")?.play()
                    }
                    self.refresh()
                }
            } catch {
                await MainActor.run {
                    self.busy = false
                    self.status = error.localizedDescription
                }
            }
        }
    }

    func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    func stop(_ share: Share) {
        busy = true
        Task.detached(priority: .userInitiated) {
            try? Tnshare.stop(token: share.token)
            await MainActor.run {
                self.busy = false
                self.status = "Revoked \(share.name)"
                self.refresh()
            }
        }
    }
}

// MARK: - Views

struct DropZone: View {
    @EnvironmentObject var store: Store
    @State private var targeted = false

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: targeted ? 2 : 1.5, dash: [7, 5]))
            .foregroundStyle(targeted ? Color.accentColor : Color.secondary.opacity(0.5))
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(targeted ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .frame(height: 104)
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: store.busy ? "arrow.triangle.2.circlepath" : "arrow.down.doc")
                        .font(.system(size: 26, weight: .light))
                        .symbolEffect(.pulse, isActive: store.busy)
                    Text(store.busy ? "Working…" : "Drop files here")
                        .font(.callout)
                    Text(store.destination.blurb)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
                load(providers)
                return true
            }
            .onTapGesture { chooseFiles() }
    }

    private func load(_ providers: [NSItemProvider]) {
        let group = DispatchGroup()
        var paths: [String] = []
        let lock = NSLock()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url, url.isFileURL {
                    lock.lock(); paths.append(url.path); lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) { store.share(paths: paths.sorted()) }
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.prompt = "Share"
        if panel.runModal() == .OK {
            store.share(paths: panel.urls.map(\.path))
        }
    }
}

struct ShareRow: View {
    @EnvironmentObject var store: Store
    let share: Share
    let now: Date
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: share.isHosted ? "cloud" : "desktopcomputer")
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(share.name).font(.callout).lineLimit(1).truncationMode(.middle)
                Text("\(share.isHosted ? share.host : "this Mac") · \(share.timeLeft(now: now))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            if hovering {
                Button {
                    store.copy(share.url)
                    store.status = "Link copied — \(share.name)"
                } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless)
                    .help("Copy link")

                Button { store.stop(share) } label: { Image(systemName: "xmark.circle") }
                    .buttonStyle(.borderless)
                    .help("Revoke now")
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(hovering ? Color.secondary.opacity(0.12) : .clear,
                    in: RoundedRectangle(cornerRadius: 7))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) {
            store.copy(share.url)
            store.status = "Link copied — \(share.name)"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $store.destination) {
                ForEach(Destination.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            DropZone()

            HStack {
                Text("Live links").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if !store.shares.isEmpty {
                    Text("\(store.shares.count)").font(.caption).foregroundStyle(.secondary)
                }
            }

            if store.shares.isEmpty {
                Text("Nothing shared right now.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(store.shares) { share in
                            ShareRow(share: share, now: store.tick)
                                .environmentObject(store)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }

            Divider()

            HStack(spacing: 8) {
                Text(store.status.isEmpty
                     ? (store.storage.isEmpty ? "Links expire after 24 hours." : store.storage)
                     : store.status)
                    .font(.caption)
                    .foregroundStyle(store.status.isEmpty ? .tertiary : .secondary)
                    .lineLimit(2)
                Spacer()
                if !store.shares.isEmpty {
                    Button("Revoke all") {
                        for share in store.shares { store.stop(share) }
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }
        }
        .padding(14)
        .frame(width: 380)
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    var store: Store?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        placeWindow(attempt: 0)
    }

    /// SwiftUI creates the window after launch finishes, and can place it
    /// off-screen, so poll briefly for it and park it somewhere visible.
    private func placeWindow(attempt: Int) {
        guard attempt < 25 else { return }
        guard let window = NSApp.windows.first(where: { $0.title == "TailDrop" }) else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.placeWindow(attempt: attempt + 1)
            }
            return
        }

        window.level = .floating
        window.isMovableByWindowBackground = true
        window.setFrameAutosaveName("TailDropWindow")

        if let screen = window.screen ?? NSScreen.main,
           !screen.visibleFrame.intersects(window.frame) {
            let visible = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: visible.maxX - window.frame.width - 24,
                                          y: visible.maxY - window.frame.height - 24))
        }
        window.makeKeyAndOrderFront(nil)
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        Task { @MainActor in store?.share(paths: filenames) }
        sender.reply(toOpenOrPrint: .success)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        sender.windows.first?.makeKeyAndOrderFront(nil)
        return true
    }
}

@main
struct TailDropApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = Store()

    var body: some Scene {
        Window("TailDrop", id: "main") {
            ContentView()
                .environmentObject(store)
                .onAppear { delegate.store = store }
        }
        .windowResizability(.contentSize)

        MenuBarExtra("TailDrop", systemImage: "paperplane") {
            ContentView()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }
}
