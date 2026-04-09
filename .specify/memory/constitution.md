<!--
== Sync Impact Report ==
Version change: 2.0.0 → 2.1.0 (MINOR)
Bump rationale: Auth model materially expanded — device-ID-only
  replaced with dual auth (guest via device ID + registered via
  email/password or Google OAuth). Feature gating added:
  leaderboard and private rooms require registered account.
Modified sections:
  - Technical Stack Constraints: Auth row updated to dual model
  - Security Constraints: added auth-gating rules
Previous report (2.0.0): Principle VII redefined, performance/
  security/observability sections added.
Templates requiring updates:
  - .specify/templates/plan-template.md ✅ aligned
  - .specify/templates/spec-template.md ✅ aligned
  - .specify/templates/tasks-template.md ✅ aligned
Follow-up TODOs: None
-->

# Multiplayer Tic-Tac-Toe with Nakama Constitution

## Core Principles

### I. Server Authority (NON-NEGOTIABLE)

All game state management MUST execute on the Nakama server via
the Go runtime plugin. The client MUST NOT compute or validate
game outcomes.

- Every player move MUST be validated server-side before the
  board state is mutated. Validation MUST check: correct turn
  ownership (`presence.UserId == currentTurnUserId`), valid
  cell (empty and in-bounds 0–8), and game not already finished.
- The server MUST reject invalid moves and return an `ERROR`
  opcode to the sender without broadcasting to other players.
- Win/draw detection (`checkWin`, `checkDraw`) MUST run
  exclusively inside the `MatchLoop` handler.
- The client receives board state as read-only data; it MUST
  NOT derive game results locally.
- Rejected moves MUST NOT update client-side state — the client
  MUST wait for a `STATE_UPDATE` from the server before
  rendering any board change.

**Rationale**: Server authority eliminates cheating vectors and
ensures all players observe a single canonical game state.

### II. Real-Time WebSocket Communication

Game state updates MUST be delivered to connected clients via
Nakama's real-time WebSocket transport on port 7350.

- Match events (move accepted, turn change, game over) MUST be
  broadcast to all match participants within the same tick of
  the `MatchLoop`.
- The `MatchLoop` tick rate MUST be set to 5 ticks/sec. Tic-
  Tac-Toe is turn-based; higher rates waste CPU.
- REST/RPC endpoints (`create_room`, `join_room`,
  `get_leaderboard`, `get_player_stats`) MUST be used only for
  non-real-time operations such as room management and
  leaderboard queries.
- The `nakama-js` SDK MUST be the sole transport layer on the
  frontend; direct WebSocket or fetch calls to Nakama are
  prohibited.

**Rationale**: WebSocket-first delivery minimizes latency for
interactive gameplay while keeping non-interactive flows on
simpler REST paths.

### III. Match Isolation

Each active game session MUST be a self-contained Nakama match
with its own state, independent of all other matches.

- Match state (board array, current turn, player assignments)
  MUST be scoped to a single match ID and MUST NOT leak across
  matches.
- The server MUST support multiple concurrent matches without
  shared mutable state between them. Nakama's goroutine-per-
  match model provides this by default.
- Player presence joining/leaving one match MUST NOT affect any
  other match's lifecycle.
- `MatchJoinAttempt` MUST reject any join if the match already
  has 2 players.

**Rationale**: Isolation guarantees correctness under concurrent
load and prevents cross-match contamination bugs.

### IV. Test-Driven Game Logic

Core game rules MUST be developed test-first. Tests MUST exist
before implementation for all win/draw/move-validation logic.

- Unit tests MUST cover every win condition (8 winning lines:
  3 rows, 3 columns, 2 diagonals), draw detection, invalid-
  move rejection, and turn enforcement.
- Integration tests MUST verify the full multiplayer flow:
  matchmaking → join → alternating moves → game resolution →
  leaderboard update.
- Security tests MUST verify that a player cannot move on
  behalf of an opponent (send move with wrong userId session →
  expect `NOT_YOUR_TURN` error).
- The Go runtime plugin MUST be structured so that pure game
  logic functions (`checkWin`, `checkDraw`, `applyMove`) are
  testable without a running Nakama instance.

**Rationale**: Server-authoritative logic is the trust boundary;
untested game rules are equivalent to no game rules.

### V. Containerized Infrastructure

All backend services MUST run inside Docker containers
orchestrated by Docker Compose, both locally and in production.

- The `docker-compose.yml` MUST define at minimum: Nakama
  server, PostgreSQL, and the Go plugin build step.
- Local development MUST be reproducible with a single
  `docker compose up` command (or `make dev`).
- Production deployment (DigitalOcean Droplet, 2 vCPU / 2 GB)
  MUST use the same Docker Compose definitions with
  environment-specific overrides, not a divergent setup.
- Container restart policy MUST be `always` to ensure uptime
  after unexpected exits.

**Rationale**: Container parity between local and production
eliminates environment-specific bugs and simplifies onboarding.

### VI. Mobile-First Responsive UI

The React frontend MUST be optimized for mobile viewports as the
primary target, with progressive enhancement for larger screens.

- Touch targets MUST meet minimum 44×44 px sizing.
- The game board MUST scale fluidly between 375 px and 1440 px
  viewport widths without horizontal scrolling.
- All pages (Auth, Lobby, Game Board, Leaderboard) MUST be
  usable on a mobile device without requiring desktop fallback.
- The frontend MUST be deployed to Vercel for public
  accessibility.
- Styling MUST use Tailwind CSS with shadcn/ui components for
  rapid, consistent UI development.

**Rationale**: The assignment explicitly requires mobile-optimized
responsive UI; mobile-first ensures the hardest constraint is
satisfied by default.

### VII. Disconnect & Timeout Handling

The system MUST handle player disconnections and turn timeouts
decisively to prevent stalled matches.

- When a player disconnects mid-match, the `MatchLeave` handler
  MUST immediately declare the remaining player the winner by
  forfeit and broadcast `GAME_OVER` to all remaining presences.
  The match MUST then terminate.
- There is no reconnection grace period; match state is
  transient and in-memory. Persistent data (leaderboard scores)
  lives in PostgreSQL.
- If a timed mode is enabled, each turn MUST enforce a 30-
  second deadline tracked via `TurnDeadline` in match state.
  The `MatchLoop` MUST check `time.Now().Unix() > TurnDeadline`
  on each tick and trigger automatic forfeit on expiry.
- Turn timer state MUST be broadcast to clients via a
  `TURN_TIMER` opcode so the UI can render a countdown.

**Rationale**: Immediate forfeit on disconnect prevents
indefinitely stalled matches. The spec explicitly defines
matches as transient; persistence is limited to leaderboard
data in PostgreSQL.

## Technical Stack Constraints

| Layer    | Technology              | Version / Notes                    |
|----------|-------------------------|------------------------------------|
| Frontend | React + TypeScript      | Vite build, SPA                    |
| Styling  | Tailwind CSS + shadcn/ui| Utility-first, component library   |
| SDK      | @heroiclabs/nakama-js   | Official Heroic Labs client        |
| Backend  | Nakama OSS              | Go runtime plugin, `InitModule`    |
| Language | Go                      | Match handlers + RPC + game logic  |
| Database | PostgreSQL              | Nakama-managed, no raw SQL         |
| Auth     | Nakama dual auth        | Guest (device ID) + registered (email/password, Google OAuth) |
| Hosting FE | Vercel               | CDN, public URL                    |
| Hosting BE | DigitalOcean Droplet  | Docker Compose, 2 vCPU / 2 GB     |
| CI/CD    | GitHub Actions          | Lint, test, deploy                 |

- Third-party dependencies MUST be justified; prefer Nakama
  built-in features (leaderboards, matchmaker, storage) over
  external services.
- The Go plugin MUST compile as a shared object loaded by the
  Nakama binary; Lua/TypeScript runtimes MUST NOT be used for
  game logic.
- Authentication MUST support two tiers:
  - **Guest**: Device ID auth for zero-friction entry. Guests
    can auto-matchmake and play games but MUST NOT access
    private rooms or leaderboard features.
  - **Registered**: Email/password or Google OAuth via Nakama's
    built-in auth. Registered users unlock private room
    creation/joining, leaderboard tracking, and persistent
    stats across sessions.
- Guest accounts MUST be upgradeable to registered accounts
  via the signup flow without losing the current session.
- Google OAuth MUST be configured via Nakama's social login
  integration; OAuth client credentials MUST NOT be exposed
  in client-side code.

### Performance Targets

| Metric                            | Target             |
|-----------------------------------|--------------------|
| Move → broadcast (server-side)    | < 50 ms            |
| Matchmaking wait (2 active users) | < 5 s              |
| Client state update (LAN)         | < 150 ms           |
| Client state update (4G mobile)   | < 300 ms           |
| MatchLoop tick rate               | 5 ticks/sec        |

## Security Constraints

- The client MUST only send `MOVE` opcode data; all state
  derivation is server-owned (NFR-SEC-1).
- The server MUST validate `presence.UserId` matches
  `currentTurnUserId` before applying any move (NFR-SEC-2).
- Room codes MUST be derived from the first 8 characters of the
  match ID (UUID), providing sufficient unguessability for a
  demo (NFR-SEC-3).
- Private room RPCs (`create_room`, `join_room`) MUST verify
  the caller is a registered user; guest sessions MUST be
  rejected with an authorization error.
- Leaderboard RPCs (`get_leaderboard`, `get_player_stats`) and
  leaderboard writes MUST require a registered account.
- The Nakama admin console (port 7351) MUST NOT be exposed
  publicly. Access MUST require an SSH tunnel (NFR-SEC-4).
- PostgreSQL (port 5432) MUST NOT be exposed externally.
- Only port 7350 (Nakama HTTP + WS) and port 22 (SSH) MUST be
  open on the Droplet firewall.

## Development & Quality Gates

### Code Review

- All changes MUST be submitted via pull request.
- PRs touching match handler logic MUST include test coverage
  evidence (passing unit + integration tests).

### Testing Gates

- **Pre-merge**: All unit tests MUST pass. Go plugin tests MUST
  run without a live Nakama instance for pure logic functions.
- **Post-merge**: Integration tests against a Docker Compose
  environment MUST pass before deployment.
- **Security test**: Sending a move with the wrong userId
  session MUST return `NOT_YOUR_TURN` error.
- **Disconnect test**: Closing one client mid-game MUST result
  in the other player receiving `GAME_OVER` with winner status.

### Observability

- All match events MUST be logged via `nk.Logger()` with JSON
  format output.
- Rejected moves MUST log: userId, matchId, attempted cell
  position, and rejection reason.
- Log level MUST default to INFO in production; DEBUG available
  via Nakama config override.

### Deployment Process

- Staging validation MUST precede production deployment.
- The README MUST document:
  - Architecture with component diagram.
  - Local setup: prerequisites (Docker, Go 1.21+, Node 20+),
    `make dev` command.
  - How to play: Auth → Lobby → Match → Result flow.
  - Deployment: step-by-step DigitalOcean + Vercel setup.
  - API reference: OpCodes table + RPC endpoint docs.
  - Design decisions: why server-authoritative, why Nakama,
    Go plugin vs TS runtime.
  - Testing multiplayer with two browser windows.

### Branch Strategy

- `main` is the production branch; direct pushes are prohibited.
- Feature branches follow the pattern `###-feature-name`.

## Governance

This constitution is the highest-authority document for
architectural and process decisions in this project. All pull
requests and code reviews MUST verify compliance with these
principles.

**Amendment procedure**:
1. Propose changes via a pull request modifying this file.
2. Document the rationale for each change.
3. Update the version number per semantic versioning:
   - MAJOR: Principle removal or backward-incompatible
     redefinition.
   - MINOR: New principle or materially expanded guidance.
   - PATCH: Clarifications, typo fixes, non-semantic
     refinements.
4. Update `LAST_AMENDED_DATE` to the merge date.

**Compliance review**: At the start of each new feature
specification (`/speckit.plan`), the Constitution Check section
MUST be evaluated against these principles.

**Version**: 2.1.0 | **Ratified**: 2026-04-09 | **Last Amended**: 2026-04-09
