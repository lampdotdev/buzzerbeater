import Foundation

// MARK: - Screens a game can go on

/// The app a game is watched in, whatever screen it opens on: the service the Watch button picked, or for cable the
/// channel's own app, which the person signs in to with their provider.
struct TVApp: Hashable {
    /// What the person calls it ("ESPN", "Peacock").
    var name: String
    var service: Service
}

/// How a screen would show a game: which app it opens, and whether it lands on the game itself or only on the app's
/// home screen, which the button says plainly.
struct TVPlan: Hashable {
    var screenID: String
    var screenName: String
    var app: TVApp
    var reachesGame: Bool
    /// The screen's own way to open it (a Roku's channel id and deep link).
    var appID: String
    var contentID: String?
    var mediaType: String?
}

/// A TV Buzzer Beater can put a game on. A Roku is the first kind; a Samsung, LG or Apple TV is another type that
/// says what it can open (`plan`) and opens it (`show`). The rest of the app asks `TVs` whether a game can go on a
/// TV, never which kind of TV there is.
protocol GameScreen {
    var id: String { get }
    var name: String { get }
    /// What it is, for Settings ("Roku Express").
    var model: String { get }
    /// Why it can't take games now, in words with the fix; nil when it can.
    var blocked: String? { get }
    /// How it would show a game in this app, or nil when it can't (the app isn't on it).
    func plan(for app: TVApp) -> TVPlan?
    /// Opens it, and makes sure it opened.
    func show(_ plan: TVPlan) async throws
}

// MARK: - Roku

/// A Roku, driven over its External Control Protocol (`LampRoku`): it opens the app on the TV by its channel id.
/// Which apps land on the game and which stop at their home screen is in APP.md ("Putting a game on the TV").
struct RokuScreen: GameScreen {
    let roku: LampRoku
    /// The channels on its home screen, read when it was found.
    let apps: [LampRoku.App]

    var id: String { "roku:" + roku.id }
    var name: String { roku.name }
    var model: String { roku.model }
    var blocked: String? { roku.canBeControlled ? nil : "It doesn't take commands from apps yet. " + LampRoku.setUp }

    /// Each service's channel: the id Roku gives it, and the names it goes by on a home screen, for one whose id
    /// isn't known or has changed.
    static func channel(for service: Service) -> (id: String?, names: [String])? {
        switch service {
        case .espn, .espnPlus: ("34376", ["ESPN"])
        case .peacock: ("593099", ["Peacock TV", "Peacock"])
        case .paramount: ("31440", ["Paramount Plus", "Paramount+"])
        case .foxOne: (nil, ["FOX One", "FOX ONE"])
        case .hboMax: ("61322", ["HBO Max", "Max"])
        case .prime: ("13", ["Prime Video"])
        case .appleTV: ("551012", ["Apple TV"])
        case .netflix: ("12", ["Netflix"])
        case .youtubeTV: ("195316", ["YouTube TV"])
        case .huluLive: ("2285", ["Hulu"])
        case .sling: ("46041", ["Sling TV"])
        case .fubo: (nil, ["Fubo", "fubo"])
        case .directv: (nil, ["DIRECTV", "DIRECTV STREAM"])
        case .nbaLeaguePass: (nil, ["NBA"])
        case .nflPlus: (nil, ["NFL"])
        case .mlbTV: (nil, ["MLB"])
        case .cable, .antenna: nil
        }
    }

    func plan(for app: TVApp) -> TVPlan? {
        guard roku.canBeControlled, let channel = Self.channel(for: app.service) else { return nil }
        // By its id first, then by its name: exactly, or as the start of a longer one ("Sling TV - Live Sports…").
        let installed = apps.first { $0.id == channel.id }
            ?? apps.first { app in channel.names.contains { $0.caseInsensitiveCompare(app.name) == .orderedSame } }
            ?? apps.first { app in channel.names.contains { app.name.lowercased().hasPrefix($0.lowercased() + " - ") } }
        guard let installed else { return nil }
        // No channel has been seen to land on a game from a launch (APP.md), so every one opens at its home screen.
        return TVPlan(screenID: id, screenName: name, app: app, reachesGame: false, appID: installed.id)
    }

    func show(_ plan: TVPlan) async throws {
        // A Roku busy closing the last app, or updating the one asked for, answers 503 for a few seconds.
        var tries = 0
        while true {
            do {
                try await roku.launch(appID: plan.appID, contentID: plan.contentID, mediaType: plan.mediaType)
                break
            } catch {
                tries += 1
                if tries >= 3 { throw error }
                try await Task.sleep(for: .seconds(4))
            }
        }
        // It says it launched before the app is up, and sometimes not at all: look until it's the app on screen.
        for _ in 0..<8 {
            if (try? await roku.activeApp())?.id == plan.appID { return }
            try await Task.sleep(for: .seconds(2))
        }
        throw LampRoku.Failure(message: "\(roku.name) didn't open \(plan.app.name). Open it from the Roku's home screen.")
    }
}

// MARK: - The TVs

/// The TVs Buzzer Beater can put a game on, once the person has asked it to look (Settings, Where to Watch): looking
/// asks the Mac's permission to use the local network, so it never happens by itself first.
@MainActor
final class TVs: ObservableObject {
    static let shared = TVs()

    /// The notification button that puts the game on the TV.
    static let action = "Put It on the TV"

    enum State: Equatable { case off, looking, found, none }

    @Published private(set) var screens: [any GameScreen] = []
    @Published private(set) var state: State = .off
    /// What happened when a game was last put on a TV, by game, for the card to say.
    @Published private(set) var results: [String: String] = [:]
    @Published private(set) var sending: Set<String> = []

    /// Whether the person turned it on (LampStore "tv").
    private(set) var isOn = LampStore.load(Bool.self, from: "tv") ?? false
    private var refreshing: Task<Void, Never>?

    /// At launch: looks again for the TVs found before, and every ten minutes, so a channel added since is offered.
    func start() {
        guard isOn, refreshing == nil else { return }
        refreshing = Task {
            while !Task.isCancelled {
                await look()
                try? await Task.sleep(for: .seconds(600))
            }
        }
    }

    func turnOn() {
        isOn = true
        LampStore.save(true, to: "tv")
        refreshing?.cancel()
        refreshing = nil
        start()
    }

    func turnOff() {
        isOn = false
        LampStore.save(false, to: "tv")
        refreshing?.cancel()
        refreshing = nil
        screens = []
        state = .off
    }

    func look() async {
        state = .looking
        var found: [any GameScreen] = []
        for roku in await LampRoku.find() {
            let apps = roku.canBeControlled ? ((try? await roku.apps()) ?? []) : []
            found.append(RokuScreen(roku: roku, apps: apps))
        }
        guard isOn else { return }
        screens = found
        state = found.isEmpty ? .none : .found
    }

    /// The app the game's Watch button points to, as a TV would open it.
    func app(for game: Game) -> TVApp? {
        let link = game.watchLink
        guard link.isAvailable, var service = link.service else { return nil }
        if service == .cable {
            // Cable's channels are watched in the channel's own app, signed in with the provider.
            switch Channel.of(link.broadcast ?? "") {
            case .espn, .espnPlus, .abc, .conference: service = .espn
            default: return nil
            }
        }
        let name = switch service {
        case .espn, .espnPlus: "ESPN"
        default: service.short
        }
        return TVApp(name: name, service: service)
    }

    /// How the game would go on a TV, or nil when no TV of the person's can show it: the first TV that has its app.
    func plan(for game: Game) -> TVPlan? {
        guard state == .found, let app = app(for: game) else { return nil }
        for screen in screens where screen.blocked == nil {
            if let plan = screen.plan(for: app) { return plan }
        }
        return nil
    }

    /// The button's words: what it does, plainly, and where it stops.
    func label(for plan: TVPlan) -> String {
        let screen = screens.filter { $0.blocked == nil }.count > 1 ? plan.screenName : "the TV"
        return plan.reachesGame ? "Put the game on \(screen)" : "Open \(plan.app.name) on \(screen)"
    }

    func show(gameID: String) {
        guard let game = Watcher.shared.games.first(where: { $0.id == gameID }) else { return }
        show(game)
    }

    func show(_ game: Game) {
        guard let plan = plan(for: game), let screen = screens.first(where: { $0.id == plan.screenID }),
              sending.insert(game.id).inserted else { return }
        results[game.id] = nil
        Task {
            defer { sending.remove(game.id) }
            do {
                try await screen.show(plan)
                let place = label(for: plan).replacingOccurrences(of: "Open \(plan.app.name) on ", with: "")
                results[game.id] = plan.reachesGame ? "On \(place) now." : "\(plan.app.name) is open on \(place). Pick the game there."
            } catch {
                results[game.id] = error.localizedDescription
            }
            let said = results[game.id]
            try? await Task.sleep(for: .seconds(12))
            if results[game.id] == said { results[game.id] = nil }
        }
    }
}
