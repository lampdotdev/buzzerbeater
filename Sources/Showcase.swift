import SwiftUI

/// What a reel of the app shows (`LampShowcase`): the script's games in place of ESPN's, in a window of its own, since
/// the panel opens from a menu bar a recording of the app's window doesn't have. games.json, beside showcase.json, is a
/// list of moments: `after` seconds into the recording, these games are on.
enum ScriptedGames {
    struct Frame: Decodable {
        var after: Double
        var games: [Game]
        var plays: [String: String]?
        var chances: [String: Double]?
    }

    static var frames: [Frame] {
        guard let url = LampShowcase.file("games.json"), let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Frame].self, from: data)) ?? []
    }

    @MainActor private static var window: NSWindow?

    @MainActor static func openWindow() {
        let view = ZStack {
            LinearGradient(colors: [Color(white: 0.93), Color(white: 0.84)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            PanelView()
                .environmentObject(Watcher.shared)
                .background(.background, in: RoundedRectangle(cornerRadius: 14))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        }
        let made = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 540),
                            styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        made.titlebarAppearsTransparent = true
        made.titleVisibility = .hidden
        made.isReleasedWhenClosed = false
        made.contentView = NSHostingView(rootView: view)
        made.center()
        made.makeKeyAndOrderFront(nil)
        window = made
    }
}
