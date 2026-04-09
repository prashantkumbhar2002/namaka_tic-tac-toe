# Quickstart: Local Development

## Prerequisites

| Tool | Version | Check |
|------|---------|-------|
| Docker | 24+ | `docker --version` |
| Docker Compose | v2+ | `docker compose version` |
| Go | 1.26.1 | `go version` (must match Nakama build) |
| Node.js | 20+ | `node --version` |
| npm | 10+ | `npm --version` |
| Make | any | `make --version` |

## 1. Clone and Setup

```bash
git clone <repo-url>
cd lila_nakama
```

## 2. Start Backend (Nakama + PostgreSQL)

```bash
make dev
```

This runs `docker compose up --build` which:
- Builds the Go plugin (`backend.so`) inside a Docker container
- Starts PostgreSQL on internal port 5432
- Starts Nakama on port 7350 (API/WS) and 7351 (admin console)
- Mounts the compiled plugin into the Nakama container

Verify Nakama is running:

```bash
curl http://localhost:7350/healthcheck
```

Access admin console (local only):

```
http://localhost:7351
Username: admin
Password: password  (change in production)
```

## 3. Start Frontend

```bash
cd frontend
npm install
npm run dev
```

Opens at `http://localhost:5173`. The app connects to Nakama at
`localhost:7350` by default (configured via `VITE_NAKAMA_HOST`).

## 4. Test Multiplayer

1. Open `http://localhost:5173` in **two browser tabs**
2. In both tabs: Click "Play as Guest", enter a display name
3. In both tabs: Click "Find Match"
4. Players are paired within seconds — play a full game
5. Verify moves are validated and state updates appear in both tabs

### Test Private Rooms (requires registered account)

1. In tab A: Sign up with email/password
2. In tab A: Click "Create Room" — note the room code
3. In tab B: Sign up with a different email
4. In tab B: Click "Join Room" — enter the room code
5. Play a game; verify identical behavior to auto-matchmaking

### Test Disconnect Forfeit

1. Start a match between two tabs
2. Close one tab mid-game
3. The remaining tab should show "You win! (Opponent forfeited)"

## 5. Run Backend Tests

```bash
cd backend
go test ./... -v
```

Tests run without Docker — pure game logic functions
(`checkWin`, `checkDraw`, `applyMove`) are tested in isolation.

## 6. Run Frontend Tests

```bash
cd frontend
npx vitest run
```

## 7. Build for Production

```bash
make build
```

Compiles the Go plugin and creates an optimized frontend build.

## Environment Variables

### Frontend (.env)

| Variable | Default | Description |
|----------|---------|-------------|
| VITE_NAKAMA_HOST | localhost | Nakama server hostname |
| VITE_NAKAMA_PORT | 7350 | Nakama server port |
| VITE_NAKAMA_USE_SSL | false | Use wss:// and https:// |
| VITE_NAKAMA_SERVER_KEY | defaultkey | Nakama server key |
| VITE_GOOGLE_CLIENT_ID | — | Google OAuth client ID |

### Backend (nakama-config.yml)

See `nakama-config.yml` at repo root. Key settings:
- `socket.server_key`: Must match frontend `VITE_NAKAMA_SERVER_KEY`
- `console.password`: Admin console password (never expose externally)
- `runtime.go_entrypoint`: Must be `"InitModule"`
- `google_auth.credentials_json`: Path to Google OAuth credentials

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make dev` | Start full stack locally (docker compose up --build) |
| `make build` | Build Go plugin + frontend production bundle |
| `make test` | Run all backend + frontend tests |
| `make deploy` | Deploy to DigitalOcean (requires SSH access) |
| `make clean` | Remove build artifacts and containers |
