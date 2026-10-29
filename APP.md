Kind: companion, in the menu bar.
Look: system colors and SF Symbols, a flame for a game worth watching and a basketball when none is; orange is kept
for the Watch buttons, the flame and the tension bars. Dense scoreboard rows: team, channel and streaming-service logos (fetched on demand), rounded
monospaced scores and times, small league tags, uppercase section labels, hover highlights instead of row lines, and a
win-chance bar in the teams' own colors on good-game cards.

# Buzzer Beater

A menu bar app that watches live games across the major leagues and says when one gets good: close and late,
overtime, a big swing in win probability, an upset against the pregame line or the rankings, a comeback, a big
individual night, a no-hitter. Each good game gets one notification per kind of moment, with a Watch button that
opens it where the person can stream it. Scores come from ESPN's public scoreboard every minute; there's no key
or account.

A click on the icon (a flame and the number of good games, or a basketball) opens a panel:

- **Good games**: a card for each, with its headline ("Oilers up 1 with 6:53 left"), the latest key play, the
  score, the clock and a Watch button.
- **Just ended**: games it showed as good that have finished, with Highlights once ESPN posts the recap.
- **Also live**: every other live game as a row (league, score, clock, a watch button).
- **Coming up**: when nothing is live, the next few games worth a look today and tomorrow, ranked from the
  pregame line, the teams' records, rankings and national TV.

At the foot, Settings, refresh with how long ago it checked, Lamp's wand and Quit. Settings has the leagues (each with its own description of a good game, in
plain words), notifications, where the person lives (for regional channels), the streaming services they have,
their TV, alerts only for games they can watch, and Open at Login.

Once the person has had it find their Roku (Settings, Where to Watch, TV), a good game whose app is on the Roku gets a
line under its card, "Open ESPN on the TV", and its notification a Put It on the TV button. Nothing about a TV shows
until then, or when no TV of theirs has the game's app.

## Code

- `App.swift`: the `LampMenuBar` scene (the panel, the icon with the count) and the Settings scene.
- `PanelView.swift`: the panel: header with refresh and Lamp's wand, good-game cards, Just ended
  cards, the Also live list, Coming up (`UpcomingRow`), Settings and Quit.
- `Scores.swift`: `League` (which leagues there are and which are on at first), `Game` and `Team`, `WatchSettings`
  (LampStore "settings"), and `Watcher`, the one model: it polls ESPN with `LampSchedule`, parses the scoreboard and
  keeps the pregame lines (LampStore "lines").
- `Excitement.swift`: turns a live game into a `Buzz` (a score from 0 to 100, a headline, a key for the kind of
  moment). With win probability, a game near 50/50 late or with a big swing in the last minutes is tense; without
  it (hockey, soccer), the score rules decide.
- `Summaries.swift`: ESPN's game summary per game (`GameDetail`: win probability, the latest key play, the
  highlights clip), fetched for the games that matter, and `FlaggedGame` (LampStore "flagged"): games it showed as
  good, kept so it can offer highlights once they end.
- `Upcoming.swift`: today's and tomorrow's games when nothing is live, and `previewScore`, how they're ranked.
- `Interests.swift`: each league's description of a good game. A league whose description the person changed
  is judged by the AI (`LampAI.decideEach`) against that description instead of the built-in rules, falling back
  to the rules when no AI is set up.
- `Alerts.swift`: notifications (once per game per moment, LampStore "alerts") and which network streams where.
- `Streaming.swift`: the person's services and the channels each carries, the best link for the Watch button,
  and team cities for what's local (LampStore "teamCities").
- `TV.swift`: putting a game on a TV. `GameScreen` is what a TV can do (`plan` for a game's app, `show` it), `RokuScreen`
  the Roku's (through `LampRoku`), and `TVs` the TVs found, which the card and the notification ask (`plan(for:)`),
  never which kind of TV it is. LampStore "tv" says the person turned it on.
- `Logos.swift`: `LogoCache` (team logos from ESPN, downloaded once when first shown and kept in LampStore.folder/logos),
  `TeamLogo` (with an abbreviation circle as fallback), `Team.tint` (the team's color), and `NetworkLogos`/`NetworkBadge`
  (channel and streaming logos: each site's icon from Google's icon service, matched by name, fetched on demand).
- `SettingsView.swift`: Settings, in three tabs on the standard gray window background: Leagues (a System
  Settings-style list with league logos and switches; double-click opens a sheet to describe a worthwhile game; + adds
  an any-league moment), Where to Watch (location and services) and General (alerts, Open at Login). Resizable.
- `capabilities.json`: a background app, so alerts come while the panel is closed, and the local network's reason,
  for finding the Roku.

## Data

All in LampStore: `settings`, `lines`, `alerts`, `flagged`, `moments`, `teamCities` and `tv`. There's no example
content: the games are live, and when there are none the panel says so and shows what's coming up.

## Easy to change

- Which leagues are on at first: `League.defaults`. A league's built-in description: `League.defaultCriteria`.
- What counts as tense, and the headlines: `Excitement.swift`.
- The notification wording: `Alerts.swift` and `Summaries.swift`.
- How often it checks: the schedule in `Watcher`.
- What the panel shows: `PanelView.swift`. The win probability behind each card is `GameDetail.winProbability`.
- Another kind of TV (Samsung, LG, Apple TV): a type that conforms to `GameScreen`, found in `TVs.look`.

## Putting a game on the TV

A Roku opens a channel over its External Control Protocol (`/launch/<channel id>`), with a `contentId` and `mediaType`
for a deep link that the channel itself must support. Buzzer Beater opens the channel of the service its Watch button
picked (for cable, ESPN's channels in the ESPN app), found among the Roku's channels by the id Roku gives it, else by
its name. What was seen on a Roku Express (Roku OS 15.3), launching each channel from its home screen:

| Service | Channel id | Opens | Lands on the game |
| --- | --- | --- | --- |
| ESPN, ESPN+ | 34376 | yes | no: launched with ESPN's stream id (`contentId`, `mediaType` live or episode), it opened but played nothing within 30 seconds (a Roku doesn't show what another channel has on screen, so whether it stopped at a profile or sign-in screen isn't known) |
| Peacock | 593099 | yes | no game id to give it (ESPN's scoreboard has none) |
| Paramount+ | 31440 | yes | no game id to give it |
| HBO Max | 61322 | yes | no game id to give it |
| Hulu + Live TV | 2285 | yes, on a second try | no game id to give it |
| Apple TV | 551012 | yes, slowly the first time (it updated) | no game id to give it |
| NBC, CBS (cable) | 68669, 619667 | yes | no game id to give it |
| YouTube TV | 195316 | no: the Roku answered 204 and stayed on its home screen | — |
| Prime Video | 13 | no: the Roku answered 503 three times | — |
| Sling TV | 46041 | no: the Roku answered 503 three times | — |
| YouTube (control) | 837 | yes | yes: a video id as `contentId` plays the video |

So every service opens at its home screen, and the line says so: "Open ESPN on the TV", then "ESPN is open on the TV.
Pick the game there." A launch is tried three times (a Roku closing the last app, or updating the one asked for, answers
503 for a few seconds) and counts only once the Roku says that app is in front; otherwise the line says it didn't open
and to open it from the Roku's home screen. A channel that does land on a game later gets `reachesGame` and its deep link
in `RokuScreen.plan`, and the line says "Put the game on the TV". Fox One, Fubo, DIRECTV and the league apps are found by
name, untried.

