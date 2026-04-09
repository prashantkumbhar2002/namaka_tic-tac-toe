# Research: Multiplayer Tic-Tac-Toe with Nakama OSS + Go Runtime

**Date**: 2026-04-10  
**Sources**: Heroic Labs official docs, nakama-common v1.45.0 source (runtime.go), pkg.go.dev, GitHub issues, web benchmarks

---

## 1. Nakama Go Plugin Build Mode

### Decision

Use `go build -buildmode=plugin -trimpath` to compile a `.so` shared object. The Go toolchain version **must exactly match** the version Nakama was built with. For Nakama's latest release (using nakama-common v1.45.0), this is **Go 1.26.1**.

### Details

| Item | Value |
|------|-------|
| Build command | `go build -buildmode=plugin -trimpath -o ./backend.so` |
| Module path | `github.com/heroiclabs/nakama-common` (v1.45.0, published 2026-03-20) |
| Runtime import | `github.com/heroiclabs/nakama-common/runtime` |
| Go version | 1.26.1 (must match server exactly; run with `--logger.level DEBUG` to verify) |
| Platform | Linux only for native builds; use Docker plugin-builder image for cross-compilation |
| Entry point | `func InitModule(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, initializer runtime.Initializer) error` |

**Setup steps:**

```bash
go mod init "myproject/server"
go get -u "github.com/heroiclabs/nakama-common/runtime"
go mod vendor
go build -buildmode=plugin -trimpath -o ./backend.so
```

### Rationale

The `plugin` buildmode has been Nakama's approach since Go runtime support was introduced. It remains unchanged in 2026. The `-trimpath` flag ensures reproducible builds. Heroic Labs provides a Docker `pluginbuilder` image that bundles the correct Go version.

### Alternatives Considered

| Alternative | Why Rejected |
|-------------|-------------|
| TypeScript runtime | Go chosen for type safety, performance in authoritative match logic, and access to full Go ecosystem |
| Lua runtime | Lacks type safety and mature package ecosystem; harder to test |
| gRPC sidecar | Adds network hop latency; plugin runs in-process with zero serialization overhead |

---

## 2. Google OAuth with Nakama OSS

### Decision

Configure Google OAuth credentials in `config.yml` under `google_auth`. The client calls `client.authenticateGoogle(token, create, username)` from nakama-js. The token is a Google ID token (JWT) obtained from Google Sign-In on the client.

### Server Configuration (`config.yml`)

```yaml
google_auth:
  credentials_json: "/path/to/google-credentials.json"
```

The credentials JSON is obtained from the Google Cloud Console (OAuth 2.0 credentials or service account with Games API access). For Google Play Games Plugin v0.11.x+, you need GPGS server-side access credentials with `Players:get` read scope.

### Client-Side (nakama-js)

```typescript
// Google Sign-In returns an ID token
const session = await client.authenticateGoogle(
  googleIdToken,   // Google OAuth ID token
  true,            // create account if doesn't exist
  "username"       // optional custom username
);
```

**Yes**, nakama-js has a built-in `authenticateGoogle()` method. The REST endpoint is:

```
POST /v2/account/authenticate/google?create=true&username=mycustomusername
Authorization: Basic base64(ServerKey:)
Body: {"token": "google-id-token"}
```

### Server-Side Go (for custom auth hooks)

```go
userid, username, created, err := nk.AuthenticateGoogle(ctx, "some-id-token", "username", true)
```

### Rationale

Nakama has first-class Google authentication support. No custom RPC or middleware needed -- just configure credentials and use the built-in SDK method. This avoids rolling custom OAuth token validation.

### Alternatives Considered

| Alternative | Why Rejected |
|-------------|-------------|
| Custom RPC with manual Google token verification | Unnecessary complexity; Nakama validates tokens natively |
| Firebase Auth bridge | Adds an extra dependency; Nakama handles Google directly |
| Email-only auth | Worse UX for mobile/web games; Google sign-in is frictionless |

---

## 3. Nakama Account Linking (Guest to Registered)

### Decision

Use Nakama's built-in linking API. A guest authenticates via `authenticateDevice()`, then upgrades by calling `linkGoogle()` or `linkEmail()` on the client. The existing session **persists** after linking -- no re-authentication required. The user ID remains the same.

### Client-Side (nakama-js)

**Step 1: Guest login**
```typescript
const deviceId = generateOrRetrieveDeviceId();
const session = await client.authenticateDevice(deviceId, true, "guest_username");
```

**Step 2a: Link Google account**
```typescript
await client.linkGoogle(session, { token: googleIdToken });
```

**Step 2b: Link email/password**
```typescript
await client.linkEmail(session, {
  email: "user@example.com",
  password: "securepassword"
});
```

### Server-Side Go Functions

```go
// Link Google to existing user
err := nk.LinkGoogle(ctx, userID, "google-id-token")

// Link email/password to existing user
err := nk.LinkEmail(ctx, userID, "email@example.com", "password")

// Link device to existing user
err := nk.LinkDevice(ctx, userID, "device-id")
```

### Session Behavior

- **Session persists**: After linking, the current session token remains valid. No need to re-authenticate.
- **User ID unchanged**: The same user ID is retained; a new authentication link is simply added to the account.
- **Multiple links**: An account can have multiple links simultaneously (device + Google + email). The user can log in via any linked method.
- **Unlinking**: Use `nk.UnlinkDevice()` / `client.unlinkDevice()` to remove the guest device link after upgrading (optional).

### Rationale

Nakama's linking model is designed exactly for the guest-to-registered upgrade flow. It preserves all user data (match history, leaderboard records, storage objects) because the user ID doesn't change.

### Alternatives Considered

| Alternative | Why Rejected |
|-------------|-------------|
| Create new account + migrate data | Complex, error-prone, loses match history references |
| Custom merge RPC | Unnecessary; built-in linking handles this cleanly |
| Skip guest accounts entirely | Worse UX; frictionless onboarding is important for games |

---

## 4. Frontend Testing with Vite + React

### Decision

Use **Vitest** as the test runner for the React + Vite + TypeScript frontend.

### Rationale

| Factor | Vitest | Jest |
|--------|--------|------|
| Vite integration | Native -- shares `vite.config.ts`, zero extra config | Requires separate config, `ts-jest` or `@swc/jest` |
| TypeScript support | Built-in via esbuild, zero-config | Needs transformer setup |
| ESM support | Native | Improved in Jest 30 (June 2025) but still requires config |
| Speed | 2-8x faster on TS projects (14s vs 52-68s cold start on 200-file benchmark) | Slower due to separate transform pipeline |
| API compatibility | ~95% compatible with Jest API (`vi.fn()` vs `jest.fn()`) | Industry standard API |
| Adoption (new TS projects) | ~65% of new TS project setups in 2026 | ~35%, mostly legacy/existing codebases |
| Weekly downloads | 9-20M (growing) | 20-30M (stable/legacy dominance) |

### Setup

```bash
npm install -D vitest @testing-library/react @testing-library/jest-dom jsdom
```

```typescript
// vite.config.ts
/// <reference types="vitest" />
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: './src/test/setup.ts',
  },
});
```

### Alternatives Considered

| Alternative | Why Rejected |
|-------------|-------------|
| Jest 30 | Viable but requires additional config for Vite/TS projects; no advantage over Vitest for new Vite projects |
| Playwright (for unit tests) | Playwright excels at E2E, not unit/component tests; use alongside Vitest for E2E |
| Bun test runner | Less mature ecosystem, fewer integrations with React Testing Library |

---

## 5. Nakama Leaderboard API

### Decision

Use `nk.LeaderboardCreate()` at server init (inside `InitModule`) and `nk.LeaderboardRecordWrite()` to submit scores from authoritative match logic.

### LeaderboardCreate

```go
func (nk NakamaModule) LeaderboardCreate(
    ctx context.Context,
    id string,                       // unique leaderboard ID
    authoritative bool,              // true = server-only writes
    sortOrder string,                // "asc" or "desc"
    operator string,                 // "best", "set", "incr", "decr"
    resetSchedule string,            // CRON format, e.g. "0 0 * * 1" (weekly Monday)
    metadata map[string]interface{}, // optional metadata
) error
```

**Example (in InitModule):**
```go
id := "tictactoe_wins"
authoritative := true
sort := "desc"
operator := "best"
reset := "0 0 * * 1"  // weekly reset every Monday
metadata := map[string]interface{}{"game": "tictactoe"}

if err := nk.LeaderboardCreate(ctx, id, authoritative, sort, operator, reset, metadata); err != nil {
    logger.WithField("err", err).Error("Leaderboard create error.")
    return err
}
```

### LeaderboardRecordWrite

```go
func (nk NakamaModule) LeaderboardRecordWrite(
    ctx context.Context,
    id string,                        // leaderboard ID
    ownerID string,                   // user ID (owner of the record)
    username string,                  // display username
    score int64,                      // primary score
    subscore int64,                   // secondary tiebreaker score
    metadata map[string]interface{},  // optional per-record metadata
    overrideOperator *int,            // nil = use leaderboard default; or override
) (*api.LeaderboardRecord, error)
```

**Example (after a match win):**
```go
record, err := nk.LeaderboardRecordWrite(
    ctx,
    "tictactoe_wins",         // leaderboard ID
    winnerUserID,             // owner
    winnerUsername,            // username for display
    1,                        // score (1 win)
    0,                        // subscore
    map[string]interface{}{   // metadata
        "opponent": loserUserID,
    },
    nil,                      // use leaderboard's default operator
)
```

### Operator Behavior

| Operator | Behavior | Use Case |
|----------|----------|----------|
| `best` | Keeps the highest score (desc) or lowest (asc). No-ops if submitted score is worse. | High score boards, fastest time |
| `set` | Always replaces with the submitted value | Rating/ELO systems, current level |
| `incr` | Adds the submitted value to the existing score | Win counters, total points |
| `decr` | Subtracts the submitted value from the existing score | Penalty systems |

**Override operator**: Pass a non-nil `*int` to `overrideOperator` to override the leaderboard's default operator for a single write. Constants available:

```go
// From the Nakama API
apiOverrideOperatorBest    = 1
apiOverrideOperatorSet     = 2
apiOverrideOperatorIncr    = 3
apiOverrideOperatorDecr    = 4
```

### Client-Side (nakama-js) -- for non-authoritative leaderboards

```typescript
const record = await client.writeLeaderboardRecord(session, "level1", {
  score: 100,
  subscore: 50,
  metadata: JSON.stringify({ level: "hard" }),
});
```

For **authoritative leaderboards** (`authoritative: true`), clients cannot submit scores directly. All writes must go through server-side code (match handler or RPC).

### Rationale

For a Tic-Tac-Toe game, use `authoritative: true` to prevent score manipulation. The `incr` operator with score=1 per win makes a natural "total wins" leaderboard. Use `best` for tracking win streaks.

### Alternatives Considered

| Alternative | Why Rejected |
|-------------|-------------|
| Tournaments API | Overkill for simple win tracking; tournaments add join requirements and duration windows |
| Custom storage-based ranking | Loses built-in pagination, reset schedules, and rank calculation |
| Non-authoritative leaderboard | Clients could submit fake scores; authoritative prevents cheating |

---

## Summary Table

| # | Topic | Decision | Key Detail |
|---|-------|----------|------------|
| 1 | Go plugin build | `go build -buildmode=plugin -trimpath` | Go 1.26.1, nakama-common v1.45.0 |
| 2 | Google OAuth | `google_auth.credentials_json` in config.yml | nakama-js: `client.authenticateGoogle(token, create, username)` |
| 3 | Account linking | `client.linkGoogle(session, {token})` | Session persists, user ID unchanged |
| 4 | Frontend testing | Vitest | Native Vite integration, 2-8x faster than Jest on TS |
| 5 | Leaderboard API | `nk.LeaderboardCreate()` + `nk.LeaderboardRecordWrite()` | Use `authoritative: true` + `incr` operator for win counting |
