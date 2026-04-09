# Implementation Plan: Multiplayer Tic-Tac-Toe with Nakama

**Branch**: `main` | **Date**: 2026-04-09 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/multiplayer-tictactoe/spec.md`

## Summary

Build a production-ready, server-authoritative multiplayer
Tic-Tac-Toe game. The Nakama Go runtime plugin handles all game
logic (move validation, win/draw detection, matchmaking, private
rooms, leaderboard). The React frontend is a thin client that
sends `MOVE` opcodes and renders server-broadcast state. Two auth
tiers: guest (device ID, auto-matchmaking only) and registered
(email/password or Google OAuth, unlocks private rooms +
leaderboard). Deployed on DigitalOcean (Nakama + PostgreSQL via
Docker Compose) and Vercel (React SPA).

## Technical Context

**Language/Version**: Go 1.26.1 (backend, must match Nakama build), TypeScript 5.x (frontend)
**Primary Dependencies**: Nakama OSS (nakama-common v1.45.0), @heroiclabs/nakama-js, React 18, Vite 6, Tailwind CSS 4, shadcn/ui
**Storage**: PostgreSQL (Nakama-managed — accounts, leaderboard, storage objects)
**Testing**: `go test` (backend unit + integration), Vitest + React Testing Library (frontend)
**Target Platform**: Web browser SPA (Vercel CDN) + Linux server (Docker on DigitalOcean Droplet)
**Project Type**: Real-time multiplayer web game (server-authoritative)
**Performance Goals**: <50ms server-side move processing, <5s matchmaking, 5 ticks/sec MatchLoop
**Constraints**: <300ms client state update on 4G, <100 concurrent players (demo scale), 2 vCPU / 2 GB RAM
**Scale/Scope**: ~100 concurrent players, 6 frontend pages/views, 6 Go source files, 1 Docker Compose stack

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Status | Evidence |
|---|-----------|--------|----------|
| I | Server Authority | ✅ PASS | All game logic in Go plugin MatchLoop; client sends MOVE opcode only |
| II | Real-Time WebSocket | ✅ PASS | nakama-js SDK for all transport; 5 ticks/sec; REST only for RPCs |
| III | Match Isolation | ✅ PASS | Nakama goroutine-per-match; state scoped to match ID; max 2 players enforced |
| IV | Test-Driven Game Logic | ✅ PASS | go test for pure logic (checkWin, checkDraw, applyMove); Vitest for frontend |
| V | Containerized Infrastructure | ✅ PASS | docker-compose.yml with Nakama + PostgreSQL + Go build; restart: always |
| VI | Mobile-First Responsive UI | ✅ PASS | Tailwind CSS + shadcn/ui; 375px–1440px fluid; 44px touch targets |
| VII | Disconnect & Timeout Handling | ✅ PASS | MatchLeave → immediate forfeit; TurnDeadline for timed mode |
| — | Dual Auth Model | ✅ PASS | Guest (device ID) + Registered (email/Google OAuth); linking API for upgrade |
| — | Security Constraints | ✅ PASS | Authoritative leaderboard; auth-gated RPCs; firewall: 7350+22 only |

All gates pass. No violations requiring justification.

## Project Structure

### Documentation (this feature)

```text
specs/multiplayer-tictactoe/
├── plan.md              # This file
├── research.md          # Phase 0 output — technology decisions
├── data-model.md        # Phase 1 output — entities & state machine
├── quickstart.md        # Phase 1 output — local dev setup
├── contracts/           # Phase 1 output — OpCode + RPC contracts
│   ├── opcodes.md
│   └── rpc-endpoints.md
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
backend/
├── go.mod
├── go.sum
├── main.go                  # InitModule — register handlers, create leaderboard
├── match_handler.go         # MatchInit, MatchJoinAttempt, MatchJoin, MatchLoop, MatchLeave, MatchTerminate
├── rpc.go                   # create_room, join_room, get_leaderboard, get_player_stats
├── game_logic.go            # checkWin, checkDraw, applyMove (pure functions)
├── leaderboard.go           # leaderboard write/read helpers
├── auth.go                  # isRegisteredUser helper, auth-gating checks
├── types.go                 # MatchState, GameStatus, OpCode constants, message payloads
└── game_logic_test.go       # Unit tests for pure game logic

frontend/
├── src/
│   ├── lib/
│   │   └── nakama.ts        # Nakama client singleton + session management
│   ├── pages/
│   │   ├── AuthPage.tsx      # Guest entry + Sign Up / Sign In forms
│   │   ├── LobbyPage.tsx     # Find Match, Create Room, Join Room, Leaderboard
│   │   └── GamePage.tsx      # Board, player info, result overlay
│   ├── components/
│   │   ├── Board.tsx         # 3×3 grid, cell click handler
│   │   ├── PlayerInfo.tsx    # Current turn, symbol, display name
│   │   ├── ResultOverlay.tsx # Win/loss/draw screen + Back to Lobby
│   │   └── Leaderboard.tsx   # Top-10 table
│   ├── hooks/
│   │   ├── useNakama.ts      # Auth state, session, account tier
│   │   ├── useMatch.ts       # WebSocket match state machine
│   │   └── useMatchmaker.ts  # Auto-matchmaking lifecycle
│   └── test/
│       └── setup.ts          # Vitest setup (jsdom, testing-library)
├── package.json
├── vite.config.ts
├── tailwind.config.ts
└── tsconfig.json

docker-compose.yml            # Nakama + PostgreSQL + Go plugin build
docker-compose.prod.yml       # Production overrides (restart, env vars)
nakama-config.yml             # Nakama server configuration
Makefile                      # make dev, make build, make deploy
README.md                     # Architecture, setup, deployment, testing
```

**Structure Decision**: Web application layout (backend/ + frontend/)
matching the assignment's requirement sheet. The backend is a Go
module compiled as a Nakama plugin (not a standalone server). The
frontend is a React SPA deployed separately to Vercel. Added
`auth.go` for the dual-auth gating logic not present in the
original assignment structure.

## Complexity Tracking

No Constitution Check violations. No complexity justifications needed.
