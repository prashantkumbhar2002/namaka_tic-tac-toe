# Tasks: Multiplayer Tic-Tac-Toe with Nakama

**Input**: Design documents from `/specs/multiplayer-tictactoe/`
**Prerequisites**: plan.md, spec.md, data-model.md, contracts/, research.md, quickstart.md

**Tests**: Constitution Principle IV mandates test-driven game logic. Test tasks are included for backend game logic and critical integration paths.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Backend**: `backend/` (Go module, Nakama plugin)
- **Frontend**: `frontend/src/` (React SPA)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization, Docker environment, build tooling

- [ ] T001 Create directory structure per plan.md (backend/, frontend/src/{lib,pages,components,hooks,test}/)
- [ ] T002 Initialize Go module in backend/ with `go mod init` and add `github.com/heroiclabs/nakama-common` dependency
- [ ] T003 [P] Initialize React project in frontend/ with `npm create vite@latest -- --template react-ts`
- [ ] T004 [P] Create docker-compose.yml at repo root (Nakama + PostgreSQL + Go plugin builder)
- [ ] T005 [P] Create nakama-config.yml at repo root (server key, ports, runtime entrypoint, google_auth, logging)
- [ ] T006 [P] Create Makefile at repo root (targets: dev, build, test, deploy, clean)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core types, pure game logic, auth helpers, frontend SDK — MUST complete before ANY user story

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T007 Define MatchState struct, GameStatus enum, OpCode constants, and message payload types in backend/types.go
- [ ] T008 [P] Implement pure game logic functions (checkWin, checkDraw, applyMove) in backend/game_logic.go
- [ ] T009 [P] Write unit tests for checkWin (all 8 lines), checkDraw, applyMove (valid/invalid) in backend/game_logic_test.go
- [ ] T010 [P] Implement isRegisteredUser helper (check email or Google linked) in backend/auth.go
- [ ] T011 Implement InitModule with RegisterMatch, RegisterMatchmakerMatched, and all RPC registrations in backend/main.go
- [ ] T012 [P] Create Nakama client singleton with session management (create, restore, refresh) in frontend/src/lib/nakama.ts
- [ ] T013 [P] Configure Tailwind CSS 4 + shadcn/ui in frontend/ (tailwind.config.ts, globals.css, cn utility)
- [ ] T014 [P] Configure Vitest with jsdom and React Testing Library in frontend/vite.config.ts and frontend/src/test/setup.ts

**Checkpoint**: Foundation ready — game logic tested, types defined, SDK configured. User story work can begin.

---

## Phase 3: User Story 1 — Guest Entry and Lobby Access (Priority: P1) 🎯 MVP

**Goal**: Guest players can authenticate via device ID, set a display name, and access the lobby with "Find Match" enabled. Private rooms and leaderboard show registration prompts.

**Independent Test**: Open fresh tab → "Play as Guest" → set name → lobby renders → "Find Match" enabled → "Create Room" / "Leaderboard" show signup prompt.

### Implementation for User Story 1

- [ ] T015 [US1] Implement useNakama hook (device auth, display name set/update, account tier detection, session persistence) in frontend/src/hooks/useNakama.ts
- [ ] T016 [US1] Build AuthPage with "Play as Guest" button and display name input (1–16 chars, alphanumeric + spaces) in frontend/src/pages/AuthPage.tsx
- [ ] T017 [US1] Build LobbyPage with "Find Match" enabled, "Create Room" / "Join Room" / "Leaderboard" gated with signup prompts in frontend/src/pages/LobbyPage.tsx
- [ ] T018 [US1] Add client-side routing (Auth → Lobby → Game) with session guard in frontend/src/App.tsx

**Checkpoint**: Guest can authenticate, set name, and see the lobby. Gated features prompt signup.

---

## Phase 4: User Story 1b — Register or Sign In (Priority: P1)

**Goal**: Guest players can upgrade to registered accounts via email/password or Google OAuth. Registered users can sign in on any device. Session persists after linking.

**Independent Test**: As guest → "Sign Up" → email/password → session persists → "Create Room" unlocked. New tab → "Sign In" with email → same account restored.

### Implementation for User Story 1b

- [ ] T019 [US1b] Add Google OAuth credentials configuration in nakama-config.yml
- [ ] T020 [US1b] Add email/password signup and sign-in forms to AuthPage in frontend/src/pages/AuthPage.tsx
- [ ] T021 [P] [US1b] Add Google OAuth sign-in button to AuthPage in frontend/src/pages/AuthPage.tsx
- [ ] T022 [US1b] Implement account linking (linkEmail, linkGoogle) and direct sign-in (authenticateEmail, authenticateGoogle) in frontend/src/hooks/useNakama.ts
- [ ] T023 [US1b] Update LobbyPage to unlock "Create Room", "Join Room", "Leaderboard" when account tier is registered in frontend/src/pages/LobbyPage.tsx

**Checkpoint**: Dual auth works — guests upgrade seamlessly, registered users sign in cross-device. Gated features unlock.

---

## Phase 5: User Story 2 — Play a Full Game via Auto-Matchmaking (Priority: P1)

**Goal**: Two players click "Find Match", are paired by Nakama matchmaker, and play a complete Tic-Tac-Toe game with server-validated moves. Game ends with win, draw, or error handling.

**Independent Test**: Two browser tabs → "Find Match" in both → paired within 5s → alternate moves → win/draw detected → GAME_OVER broadcast to both.

### Tests for User Story 2

- [ ] T024 [P] [US2] Write unit tests for MatchJoinAttempt (max 2, reject duplicate userId) in backend/match_handler_test.go
- [ ] T025 [P] [US2] Write unit tests for move validation (turn enforcement, invalid cell, game-over rejection) in backend/match_handler_test.go

### Implementation for User Story 2

- [ ] T026 [US2] Implement MatchInit (initialize empty board, set status WAITING) in backend/match_handler.go
- [ ] T027 [US2] Implement MatchJoinAttempt (reject if full or duplicate userId) in backend/match_handler.go
- [ ] T028 [US2] Implement MatchJoin (assign X/O by join order, broadcast PLAYER_JOINED) in backend/match_handler.go
- [ ] T029 [US2] Implement MatchLoop (read messages, dispatch by opcode, validate moves, call checkWin/checkDraw, broadcast STATE_UPDATE/GAME_OVER/ERROR) in backend/match_handler.go
- [ ] T030 [US2] Implement RegisterMatchmakerMatched hook (pair 2 players → MatchCreate) in backend/main.go
- [ ] T031 [US2] Implement useMatchmaker hook (addMatchmaker, onMatchmakerMatched, joinMatch, cancel) in frontend/src/hooks/useMatchmaker.ts
- [ ] T032 [US2] Implement useMatch hook (WebSocket state machine: handle STATE_UPDATE, GAME_OVER, PLAYER_JOINED, ERROR opcodes) in frontend/src/hooks/useMatch.ts
- [ ] T033 [P] [US2] Build Board component (3×3 responsive grid, cell click sends MOVE opcode, 44px touch targets) in frontend/src/components/Board.tsx
- [ ] T034 [P] [US2] Build PlayerInfo component (current turn indicator, player symbol, display name) in frontend/src/components/PlayerInfo.tsx
- [ ] T035 [US2] Build GamePage (wire Board + PlayerInfo + useMatch, display match state) in frontend/src/pages/GamePage.tsx
- [ ] T036 [US2] Build ResultOverlay (win/lose/draw display, winning line highlight, "Back to Lobby" button) in frontend/src/components/ResultOverlay.tsx

**Checkpoint**: Core gameplay loop complete. Two players can matchmake, play, and see results. This is the MVP.

---

## Phase 6: User Story 3 — Create and Join a Private Room (Priority: P1)

**Goal**: Registered players can create a private match, receive a room code, share it, and have another registered player join via that code. Guests are rejected.

**Independent Test**: Tab A (registered) → Create Room → note code. Tab B (registered) → Join Room with code → both in match → play full game. Tab C (guest) → Create Room → authorization error.

### Implementation for User Story 3

- [ ] T037 [US3] Implement create_room RPC (isRegisteredUser check, MatchCreate, StorageWrite room code, return matchId + roomCode) in backend/rpc.go
- [ ] T038 [US3] Implement join_room RPC (isRegisteredUser check, StorageRead room code, return matchId) in backend/rpc.go
- [ ] T039 [US3] Implement MatchTerminate (delete room code from storage via StorageDelete) in backend/match_handler.go
- [ ] T040 [US3] Add Create Room UI (call create_room RPC, display room code for sharing) to LobbyPage in frontend/src/pages/LobbyPage.tsx
- [ ] T041 [US3] Add Join Room UI (room code text input, call join_room RPC, join match via WebSocket) to LobbyPage in frontend/src/pages/LobbyPage.tsx

**Checkpoint**: Private room flow works end-to-end. Auth gating enforced server-side.

---

## Phase 7: User Story 4 — Disconnect Forfeit (Priority: P1)

**Goal**: When a player disconnects mid-game, the remaining player immediately wins by forfeit. Simultaneous disconnect = draw with no leaderboard write.

**Independent Test**: Start match in two tabs → close one tab → other tab shows "You Win! (Opponent forfeited)" within 200ms.

### Implementation for User Story 4

- [ ] T042 [US4] Implement MatchLeave (broadcast GAME_OVER with forfeit, set winner, terminate match) in backend/match_handler.go
- [ ] T043 [US4] Handle simultaneous disconnect in MatchLeave (declare draw, no leaderboard write, terminate) in backend/match_handler.go
- [ ] T044 [US4] Handle disconnect while WAITING (terminate match silently, no forfeit) in backend/match_handler.go
- [ ] T045 [US4] Display forfeit result in ResultOverlay ("Opponent forfeited" message variant) in frontend/src/components/ResultOverlay.tsx

**Checkpoint**: Disconnections handled cleanly. No stalled matches possible.

---

## Phase 8: User Story 5 — Leaderboard (Priority: P2)

**Goal**: After each game, registered players' results are recorded to a Nakama leaderboard. Players can view the top-10. Guests are excluded from both writes and reads.

**Independent Test**: Play 3 games as registered user → Leaderboard tab → verify win count and ranking. Guest → Leaderboard tab → signup prompt.

### Implementation for User Story 5

- [ ] T046 [US5] Create tictactoe_wins leaderboard (authoritative, desc, incr operator) in InitModule in backend/main.go
- [ ] T047 [US5] Implement recordWin and updateStreak helpers in backend/leaderboard.go
- [ ] T048 [US5] Integrate leaderboard writes into game-over handling in MatchLoop (write for registered players only, skip guests) in backend/match_handler.go
- [ ] T049 [P] [US5] Implement get_leaderboard RPC (isRegisteredUser check, top-10 records) in backend/rpc.go
- [ ] T050 [P] [US5] Implement get_player_stats RPC (isRegisteredUser check, own record or zeroed) in backend/rpc.go
- [ ] T051 [US5] Build Leaderboard component (top-10 table: rank, name, wins, streak) in frontend/src/components/Leaderboard.tsx
- [ ] T052 [US5] Add Leaderboard tab to LobbyPage (call get_leaderboard RPC, auth-gated) in frontend/src/pages/LobbyPage.tsx

**Checkpoint**: Leaderboard tracks wins for registered players. Top-10 visible from lobby.

---

## Phase 9: User Story 6 — Timed Mode (Priority: P2)

**Goal**: Players can select "Timed" mode where each turn has a 30-second deadline. Timeout = automatic forfeit. UI shows countdown.

**Independent Test**: Start timed match → let one turn expire → server declares forfeit → countdown UI displays correctly.

### Implementation for User Story 6

- [ ] T053 [US6] Add TurnDeadline logic to MatchLoop (set deadline on turn start, check time.Now > TurnDeadline each tick, forfeit on expiry) in backend/match_handler.go
- [ ] T054 [US6] Add TURN_TIMER opcode broadcast (remaining_seconds) to MatchLoop on each tick in backend/match_handler.go
- [ ] T055 [US6] Accept mode parameter in create_room RPC and matchmaker properties in backend/rpc.go and backend/main.go
- [ ] T056 [US6] Add mode selection UI (Classic / Timed toggle) to LobbyPage matchmaking flow in frontend/src/pages/LobbyPage.tsx
- [ ] T057 [US6] Add countdown timer display to GamePage (handle TURN_TIMER opcode, render seconds remaining) in frontend/src/pages/GamePage.tsx

**Checkpoint**: Timed mode works end-to-end. Both classic and timed modes selectable.

---

## Phase 10: Polish & Deployment

**Purpose**: Documentation, production deployment, validation

- [ ] T058 [P] Write README.md (architecture diagram, local setup, deployment steps, API reference, testing instructions)
- [ ] T059 [P] Create docker-compose.prod.yml (production env overrides, restart: always, strong passwords)
- [ ] T060 Deploy Nakama + PostgreSQL to DigitalOcean Droplet via docker compose (configure firewall: 7350, 22 open; 5432, 7351 closed)
- [ ] T061 Deploy frontend to Vercel with production env vars (VITE_NAKAMA_HOST, VITE_NAKAMA_USE_SSL=true, VITE_GOOGLE_CLIENT_ID)
- [ ] T062 [P] Run quickstart.md validation (end-to-end: guest auth → matchmake → play → result)
- [ ] T063 [P] Security audit (verify admin console not public, guest RPC rejection, auth-gated endpoints)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2
- **US1b (Phase 4)**: Depends on Phase 3 (needs AuthPage and LobbyPage to exist)
- **US2 (Phase 5)**: Depends on Phase 2 (can run in parallel with US1b if Auth/Lobby scaffolded)
- **US3 (Phase 6)**: Depends on Phase 4 (requires registered accounts) + Phase 5 (requires match handlers)
- **US4 (Phase 7)**: Depends on Phase 5 (requires MatchLeave in match_handler.go)
- **US5 (Phase 8)**: Depends on Phase 5 (requires game-over handling in MatchLoop)
- **US6 (Phase 9)**: Depends on Phase 5 (extends MatchLoop with timer logic)
- **Polish (Phase 10)**: Depends on all desired user stories being complete

### User Story Dependencies

- **US1 (P1)**: After Foundational — no other story dependency
- **US1b (P1)**: After US1 — needs AuthPage and LobbyPage scaffolding
- **US2 (P1)**: After Foundational — core game loop, independent of auth UI
- **US3 (P1)**: After US1b + US2 — needs registered accounts + match handlers
- **US4 (P1)**: After US2 — extends match handler with MatchLeave
- **US5 (P2)**: After US2 — extends match handler with leaderboard writes
- **US6 (P2)**: After US2 — extends match handler with timer logic

### Within Each User Story

- Tests MUST be written and FAIL before implementation (Constitution Principle IV)
- Types/models before services
- Backend before frontend (server-authoritative — frontend renders server state)
- Core implementation before integration with other stories

### Parallel Opportunities

- T003, T004, T005, T006 can all run in parallel (Phase 1)
- T008, T009, T010, T012, T013, T014 can all run in parallel (Phase 2)
- T024, T025 tests can run in parallel (Phase 5 tests)
- T033, T034 frontend components can run in parallel (Phase 5)
- T049, T050 RPC endpoints can run in parallel (Phase 8)
- T058, T059, T062, T063 can all run in parallel (Phase 10)
- US5 and US6 can run in parallel (both extend US2, different files)

---

## Parallel Example: User Story 2

```bash
# Launch tests in parallel:
Task: "T024 — Unit tests for MatchJoinAttempt in backend/match_handler_test.go"
Task: "T025 — Unit tests for move validation in backend/match_handler_test.go"

# Launch frontend components in parallel:
Task: "T033 — Board component in frontend/src/components/Board.tsx"
Task: "T034 — PlayerInfo component in frontend/src/components/PlayerInfo.tsx"
```

---

## Implementation Strategy

### MVP First (US1 + US2 — Guest Matchmaking)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL)
3. Complete Phase 3: US1 (Guest Auth + Lobby)
4. Complete Phase 5: US2 (Core Game Loop)
5. **STOP and VALIDATE**: Two guests can matchmake and play a full game
6. Deploy/demo if ready

### Full P1 Delivery

1. MVP (above)
2. Add Phase 4: US1b (Registration)
3. Add Phase 6: US3 (Private Rooms)
4. Add Phase 7: US4 (Disconnect Forfeit)
5. **VALIDATE**: All P1 user stories complete and independently testable

### Bonus Features (P2)

1. Full P1 delivery (above)
2. Add Phase 8: US5 (Leaderboard) — can run in parallel with US6
3. Add Phase 9: US6 (Timed Mode) — can run in parallel with US5
4. Complete Phase 10: Polish & Deploy

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- Backend tasks generally precede frontend tasks (server-authoritative architecture)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
