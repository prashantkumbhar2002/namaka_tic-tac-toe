# Feature Specification: Multiplayer Tic-Tac-Toe with Nakama

**Feature Branch**: `main`
**Created**: 2026-04-09
**Status**: Draft
**Input**: Startup assignment — production-ready, server-authoritative multiplayer Tic-Tac-Toe

## Clarifications

### Session 2026-04-09

- Q: If both players disconnect simultaneously, what should happen? → A: Declare draw, terminate match, no leaderboard points awarded.
- Q: How should the rematch option work after a game ends? → A: Both players return to lobby; they must re-matchmake or create/join a new room manually.
- Q: What validation rules should apply to player display names? → A: Max 16 characters, alphanumeric + spaces only, no empty strings.
- Q: How should the leaderboard be sorted/ranked? → A: Sort by total wins descending (highest wins = rank 1).
- Q: Should the same device be allowed to join the same match in two tabs? → A: Block it — MatchJoinAttempt rejects if userId is already a presence in the match.
- Q: Auth revision — what signup method for registered accounts? → A: Both email/password and Google OAuth.
- Q: Which features are gated behind registration? → A: Leaderboard + private rooms require registration; guests can only auto-matchmake.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Guest Entry and Lobby Access (Priority: P1)

A player opens the app for the first time. They click "Play as
Guest" and are silently authenticated via device ID with no
sign-up friction. They set a display name and land on the lobby
screen. As a guest, they can only auto-matchmake ("Find Match").
Private rooms, leaderboard, and stat tracking are visible but
locked behind a "Sign Up" prompt.

**Why this priority**: Without authentication and lobby access,
no other feature is reachable. Guest entry provides the
lowest-friction path to gameplay.

**Independent Test**: Open the app in a fresh browser tab; click
"Play as Guest"; verify a session is created, display name can
be set, the lobby renders with "Find Match" enabled, and
"Create Room" / "Leaderboard" show a registration prompt.

**Acceptance Scenarios**:

1. **Given** a new device, **When** the player clicks "Play as
   Guest", **Then** Nakama creates an account via device ID auth
   and returns a valid JWT session.
2. **Given** a guest session, **When** the player enters a
   display name, **Then** the name is persisted via
   `nk.AccountUpdateId` and visible in the lobby.
3. **Given** a returning device, **When** the player opens the
   app, **Then** the existing guest account is reused (no
   duplicate creation).
4. **Given** a guest session, **When** the player attempts to
   create/join a private room or view the leaderboard, **Then**
   the UI shows a prompt to sign up or sign in.

---

### User Story 1b - Register or Sign In (Priority: P1)

A guest player (or a new visitor) wants access to private rooms,
leaderboard tracking, and persistent stats. They sign up with
email/password or Google OAuth. Existing guests can upgrade
their account without losing their current session. Returning
registered users can sign in directly.

**Why this priority**: Registration gates P0 features (private
rooms) and all persistent features. It must be available from
launch alongside guest access.

**Independent Test**: Click "Sign Up" from the lobby as a guest;
register with email/password; verify the session persists, the
account is now registered, and "Create Room" / "Leaderboard"
become accessible. Repeat with Google OAuth.

**Acceptance Scenarios**:

1. **Given** a guest in the lobby, **When** they click "Sign Up"
   and complete email/password registration, **Then** Nakama
   links email credentials to the existing device-ID account
   and the session continues without interruption.
2. **Given** a guest in the lobby, **When** they click "Sign Up
   with Google" and complete OAuth, **Then** Nakama links the
   Google identity to the existing device-ID account.
3. **Given** a registered user on a new device, **When** they
   click "Sign In" and enter email/password or use Google OAuth,
   **Then** Nakama authenticates them and restores their
   persistent stats and account.
4. **Given** a newly registered account, **When** the player
   returns to the lobby, **Then** "Create Room", "Join Room",
   and "Leaderboard" are fully accessible.

---

### User Story 2 - Play a Full Game via Auto-Matchmaking (Priority: P1)

A player clicks "Find Match" and is automatically paired with
another waiting player. They play a complete game of Tic-Tac-Toe
with the server validating every move. The game ends with a
win, loss, or draw, and both players see the result.

**Why this priority**: This is the core gameplay loop — the
primary deliverable of the assignment.

**Independent Test**: Open two browser tabs, click "Find Match"
in both, verify players are paired, alternate moves, and the
game reaches a terminal state (win or draw) with correct state
broadcast to both clients.

**Acceptance Scenarios**:

1. **Given** two players in matchmaking, **When** both are
   queued, **Then** they are paired within 5 seconds and placed
   into a match.
2. **Given** a match in progress, **When** it is a player's turn
   and they tap a valid empty cell, **Then** the server validates
   the move and broadcasts `STATE_UPDATE` to both players.
3. **Given** a match in progress, **When** a player taps an
   occupied cell or moves out of turn, **Then** the server
   returns an `ERROR` opcode and the board state is unchanged.
4. **Given** a board state with three in a row, **When** the
   winning move is played, **Then** the server broadcasts
   `GAME_OVER` with winner ID and winning line indices.
5. **Given** a full board with no winner, **When** the last cell
   is filled, **Then** the server broadcasts `GAME_OVER` with
   `"winner": "draw"`.

---

### User Story 3 - Create and Join a Private Room (Priority: P1)

A registered player creates a private room and receives a room
code. They share this code with a friend (who must also be
registered), who enters it to join the same match. The game
proceeds identically to auto-matchmaking. Guest players cannot
create or join private rooms.

**Why this priority**: Private rooms are a P0 requirement in the
assignment and provide the social sharing mechanic.

**Independent Test**: In tab A (registered user), create a room
and note the code. In tab B (registered user), enter the code
and join. Verify both players are in the same match and can play
a full game. In tab C (guest), verify "Create Room" and "Join
Room" are gated with a registration prompt.

**Acceptance Scenarios**:

1. **Given** a registered player in the lobby, **When** they
   click "Create Room", **Then** the server creates a match via
   RPC `create_room` and returns a room code (first 8 chars of
   match UUID).
2. **Given** a valid room code, **When** a registered player
   enters it and clicks "Join Room", **Then** the RPC
   `join_room` returns the match ID and the player joins via
   WebSocket.
3. **Given** a room with 2 players, **When** a third player tries
   to join, **Then** `MatchJoinAttempt` rejects them.
4. **Given** a guest session, **When** the player calls
   `create_room` or `join_room` RPC, **Then** the server returns
   an authorization error.

---

### User Story 4 - Disconnect Forfeit (Priority: P1)

During an active game, one player disconnects (closes tab,
loses network). The remaining player is immediately notified
that they have won by forfeit.

**Why this priority**: The assignment requires graceful
disconnect handling. Without it, matches can stall indefinitely.

**Independent Test**: Start a match between two tabs. Close one
tab mid-game. Verify the other tab receives `GAME_OVER` with
forfeit status within one `MatchLoop` tick.

**Acceptance Scenarios**:

1. **Given** an active match, **When** one player disconnects,
   **Then** `MatchLeave` fires and the server broadcasts
   `GAME_OVER` with the remaining player as winner.
2. **Given** a forfeit, **When** the match ends, **Then** the
   match is fully terminated (no dangling goroutine).

---

### User Story 5 - Leaderboard (Priority: P2)

After each completed game involving at least one registered
player, the server records that registered player's result to a
Nakama leaderboard. Guest results are not tracked. Registered
players can view the global top-10 from the lobby, showing rank,
display name, wins, and win streak.

**Why this priority**: Bonus feature that adds engagement and
persistence. Not required for core gameplay. Gated behind
registration to incentivize signup.

**Independent Test**: Play 3 games as a registered user with
known outcomes. Navigate to the leaderboard tab. Verify entries
reflect correct win counts and ranking order. Verify a guest
cannot access the leaderboard tab.

**Acceptance Scenarios**:

1. **Given** a completed game with a registered player, **When**
   the result is finalized, **Then** the server writes a
   leaderboard record via `nk.LeaderboardRecordWrite` for the
   registered player only.
2. **Given** a completed game where both players are guests,
   **When** the result is finalized, **Then** no leaderboard
   record is written.
3. **Given** a registered player in the lobby, **When** they open
   the leaderboard tab, **Then** the RPC `get_leaderboard`
   returns the top-10 entries sorted by total wins descending
   (highest wins = rank 1).
4. **Given** leaderboard data, **When** displayed, **Then** each
   entry shows: rank, display name, total wins, current win
   streak.
5. **Given** a guest session, **When** the player attempts to
   open the leaderboard, **Then** the UI shows a registration
   prompt.

---

### User Story 6 - Timed Mode (Priority: P2)

Players can select a "Timed" mode where each turn has a 30-second
time limit. If a player fails to move within the deadline, they
forfeit the game automatically.

**Why this priority**: Bonus feature that adds urgency and a
second game mode. Not required for core gameplay.

**Independent Test**: Start a timed match. Let one player's turn
expire without moving. Verify the server declares forfeit and
the UI displays the countdown correctly.

**Acceptance Scenarios**:

1. **Given** a timed-mode match, **When** a turn begins, **Then**
   the server sets `TurnDeadline` and broadcasts `TURN_TIMER`
   with remaining seconds.
2. **Given** a running turn timer, **When** 30 seconds elapse
   without a move, **Then** the server declares forfeit in
   `MatchLoop` and broadcasts `GAME_OVER`.
3. **Given** a timed match, **When** the player moves within the
   deadline, **Then** the timer resets for the opponent's turn.

---

### Edge Cases

- If both players disconnect simultaneously, the server declares a draw, terminates the match, and does not write any leaderboard record.
- If a player sends a move after the game has ended (status = FINISHED), the server MUST return an `ERROR` opcode with code `GAME_OVER` and ignore the move.
- If the Nakama server restarts mid-match, all in-memory match state is lost. Matches are transient by design; players must start a new match from the lobby. Only leaderboard data in PostgreSQL survives restarts.
- If the same device (same userId) opens two tabs and tries to join the same match, `MatchJoinAttempt` MUST reject the second join attempt.
- If a single player is waiting in matchmaking with no opponents, they remain in the queue. After 30 seconds (FR-MATCH-4), the UI shows a waiting state with a cancel option. The player can cancel and return to the lobby at any time.
- If a guest player attempts to call `create_room`, `join_room`, `get_leaderboard`, or `get_player_stats` RPCs, the server MUST return an authorization error. The client MUST show a registration prompt instead of calling the RPC.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-AUTH-1**: System MUST support guest authentication via device ID ("Play as Guest") with zero sign-up friction (P0)
- **FR-AUTH-2**: System MUST support registered account creation via email/password with verification (P0)
- **FR-AUTH-3**: System MUST support registered account creation via Google OAuth (P0)
- **FR-AUTH-4**: Guest accounts MUST be upgradeable to registered accounts by linking email/password or Google OAuth credentials without losing the current session (P0)
- **FR-AUTH-5**: Registered users MUST be able to sign in on any device via email/password or Google OAuth (P0)
- **FR-AUTH-6**: System MUST allow players to set/update display name via Nakama account API. Display names MUST be 1–16 characters, alphanumeric and spaces only, no empty strings (P0)
- **FR-AUTH-7**: Session tokens MUST be JWT-based, auto-refreshed by the nakama-js SDK (P0)
- **FR-AUTH-8**: Private room RPCs (`create_room`, `join_room`) MUST reject guest sessions with an authorization error (P0)
- **FR-AUTH-9**: Leaderboard RPCs and leaderboard writes MUST require a registered account (P0)
- **FR-MATCH-1**: System MUST support auto-matchmaking that pairs any two waiting players (P0)
- **FR-MATCH-2**: System MUST support private room creation with a shareable room code (P0)
- **FR-MATCH-3**: System MUST support joining a room by entering a room code (P0)
- **FR-MATCH-4**: If matchmaking exceeds 30s, system MUST show waiting state and allow cancellation (P1)
- **FR-MATCH-5**: Matchmaking SHOULD support mode selection: Classic vs Timed (P2)
- **FR-GAME-1**: Server MUST assign X to the first joiner and O to the second (P0)
- **FR-GAME-2**: Server MUST validate every move: correct turn, valid cell (empty, in-bounds 0–8) (P0)
- **FR-GAME-3**: Server MUST detect win (8 winning lines) and draw (board full, no winner) (P0)
- **FR-GAME-4**: Server MUST broadcast validated board state to both clients after every valid move (P0)
- **FR-GAME-5**: If a player disconnects mid-game, opponent MUST win by forfeit immediately (P0)
- **FR-GAME-6**: Rejected moves MUST return an error opcode; client MUST NOT update local state (P0)
- **FR-GAME-7**: Each player SHOULD get 30s per turn in timed mode; timeout = forfeit (P2)
- **FR-GAME-8**: Multiple simultaneous game sessions MUST run in full isolation (P2)
- **FR-LEADER-1**: Server SHOULD write game results to Nakama Leaderboard after each game (P2)
- **FR-LEADER-2**: Client SHOULD be able to fetch the global top-10 leaderboard, sorted by total wins descending (P2)
- **FR-LEADER-3**: Leaderboard SHOULD display: rank, display name, wins, win streak (P2)
- **FR-LEADER-4**: Player stats SHOULD persist across sessions (P2)
- **FR-UI-1**: Frontend MUST be responsive — playable on mobile (375px+) and desktop (P0)
- **FR-UI-2**: Frontend MUST display current player turn, board state, and player info (P0)
- **FR-UI-3**: Frontend SHOULD animate winning line highlight (P1)
- **FR-UI-4**: Frontend SHOULD show match result screen with a "Back to Lobby" button; there is no in-match rematch — players re-matchmake or create a new room from the lobby (P1)
- **FR-UI-5**: Frontend SHOULD display countdown timer per turn in timed mode (P2)
- **FR-UI-6**: Frontend SHOULD include a leaderboard view tab (P2)

### Key Entities

- **Player**: Authenticated user with a session token and display name. Two tiers: *Guest* (device ID only, temporary, no persistent stats) and *Registered* (email/password or Google OAuth, persistent stats, full feature access). Unique by Nakama user ID. Guest accounts can be upgraded to registered by linking credentials.
- **Match**: Active game session. Contains board state ([9]string), player map (userId→symbol), current turn, game status (WAITING|PLAYING|FINISHED), optional turn deadline.
- **Room Code**: First 8 characters of the match UUID. Used for private room sharing. Mapped to match ID via Nakama storage.
- **Leaderboard Record**: Player's cumulative stats — total wins, total losses, current win streak. Persisted in PostgreSQL via Nakama's leaderboard API.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Two players can complete a full game from matchmaking to result screen in under 2 minutes of real interaction time.
- **SC-002**: Server-side move processing (validate + broadcast) completes in < 50ms.
- **SC-003**: Auto-matchmaking pairs two queued players in < 5 seconds.
- **SC-004**: A player disconnect results in opponent receiving forfeit notification within 200ms (1 MatchLoop tick at 5/sec).
- **SC-005**: The system supports 10+ concurrent isolated matches without state leakage.
- **SC-006**: The application is publicly accessible via a Vercel URL (frontend) and a DigitalOcean IP (Nakama backend).
- **SC-007**: The README covers architecture, setup, deployment, and multiplayer testing instructions.

## Assumptions

- Players have a modern browser (Chrome, Firefox, Safari, Edge — latest 2 versions).
- Players have internet connectivity sufficient for WebSocket communication (mobile 4G or better).
- A single Nakama node (2 vCPU / 2 GB DigitalOcean Droplet) is sufficient for demo-scale load (< 100 concurrent players).
- Registered accounts support cross-device sign-in; guest (device ID) accounts are device-bound and non-recoverable.
- Password reset for email accounts is out of scope for v1; can be added later via Nakama's built-in reset flow.
- No chat or social features beyond the room code sharing mechanic.
- Leaderboard and timed mode are bonus features; the submission is complete without them.
- The Go plugin compiles as a shared object; no Lua/TypeScript runtime is used.
- Nakama OSS (not Nakama Enterprise/Cloud) is the target deployment.
