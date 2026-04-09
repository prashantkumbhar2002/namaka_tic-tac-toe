# Data Model: Multiplayer Tic-Tac-Toe with Nakama

**Date**: 2026-04-09
**Source**: spec.md, constitution v2.1.0, research.md

## Entities

### Player (Nakama Account)

Nakama manages player accounts internally. No custom schema.

| Field | Type | Source | Notes |
|-------|------|--------|-------|
| user_id | string (UUID) | Nakama-managed | Primary key, immutable |
| display_name | string | `nk.AccountUpdateId` | 1–16 chars, alphanumeric + spaces |
| device_ids | []string | Nakama auth | Guest link (device ID) |
| email | string | Nakama auth | Registered link (optional) |
| google_id | string | Nakama auth | Registered link (optional) |
| account_tier | derived | Check linked credentials | Guest = device only; Registered = email or Google linked |

**Uniqueness**: Nakama user ID (UUID). Device IDs, email, and
Google IDs are unique across accounts (Nakama enforces this).

**Tier detection** (server-side helper):

```go
func isRegisteredUser(ctx context.Context, nk runtime.NakamaModule,
    userID string) (bool, error) {
    account, err := nk.AccountGetId(ctx, userID)
    if err != nil {
        return false, err
    }
    return account.Email != "" ||
        account.GetUser().GetGoogleId() != "", nil
}
```

### MatchState (in-memory, per match)

Exists only during an active match. Not persisted to PostgreSQL.

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| Board | [9]string | ["","","",…] | "" = empty, "X" or "O" |
| Players | map[string]string | {} | userId → "X" or "O" |
| Presences | map[string]runtime.Presence | {} | userId → live presence |
| CurrentTurn | string | "" | userId whose turn it is |
| Status | GameStatus | WAITING | WAITING → PLAYING → FINISHED |
| Winner | string | "" | userId or "draw" or "forfeit:{userId}" |
| WinningLine | [3]int | [-1,-1,-1] | Indices of winning cells |
| RoomCode | string | "" | First 8 chars of match ID (private rooms) |
| Mode | string | "classic" | "classic" or "timed" |
| TurnDeadline | int64 | 0 | Unix timestamp (timed mode only) |

### GameStatus (enum)

| Value | Description | Transitions from |
|-------|-------------|-----------------|
| WAITING | Match created, < 2 players joined | (initial) |
| PLAYING | Both players present, game in progress | WAITING |
| FINISHED | Win, draw, or forfeit declared | PLAYING |

### Room Code Mapping (Nakama Storage)

Used to look up match ID from a human-friendly room code.

| Field | Type | Notes |
|-------|------|-------|
| collection | string | `"room_codes"` |
| key | string | Room code (first 8 chars of match UUID) |
| user_id | string | System user (server-owned) |
| value | JSON | `{"match_id": "<full-match-uuid>"}` |
| permission_read | int | 2 (public read) |
| permission_write | int | 0 (server-only write) |

Written via `nk.StorageWrite` in `create_room` RPC. Read via
`nk.StorageRead` in `join_room` RPC. Deleted when match ends
(in `MatchTerminate`).

### Leaderboard Record (Nakama Leaderboard)

Persisted in PostgreSQL via Nakama's leaderboard system.

| Leaderboard ID | Sort | Operator | Authoritative | Reset |
|----------------|------|----------|---------------|-------|
| `tictactoe_wins` | desc | incr | true | none (no reset) |

| Field | Type | Notes |
|-------|------|-------|
| owner_id | string | Registered player's user ID |
| username | string | Display name at time of write |
| score | int64 | Total wins (incremented by 1 per win) |
| subscore | int64 | Current win streak |
| metadata | JSON | `{"last_opponent": userId}` |

Only registered players get leaderboard writes. Guest game
results are not recorded.

## State Transitions

### Match Lifecycle

```text
                    MatchInit
                       │
                       ▼
                   ┌────────┐
                   │WAITING │ (0 or 1 player)
                   └───┬────┘
                       │ 2nd player joins (MatchJoin)
                       ▼
                   ┌────────┐
          ┌───────▶│PLAYING │◀──── valid move cycles
          │        └───┬────┘      (MatchLoop)
          │            │
          │     ┌──────┼──────┐
          │     │      │      │
          │   win    draw  forfeit
          │     │      │      │
          │     ▼      ▼      ▼
          │  ┌──────────────────┐
          │  │    FINISHED      │
          │  └────────┬─────────┘
          │           │
          │     MatchTerminate
          │     (cleanup storage)
          │
          └── player disconnects while WAITING
              → match terminated (no forfeit)
```

### Auth Tier Transitions

```text
┌──────────┐  linkEmail / linkGoogle  ┌────────────┐
│  GUEST   │ ───────────────────────▶ │ REGISTERED │
│(device ID)│                         │(email/OAuth)│
└──────────┘                          └────────────┘
     ▲                                       │
     │              authenticateEmail /       │
     │              authenticateGoogle        │
     └─────── (new device, sign in) ─────────┘
```

## OpCode Constants (Go)

```go
const (
    OpCodeMove         int64 = 1
    OpCodeStateUpdate  int64 = 1
    OpCodeGameOver     int64 = 2
    OpCodePlayerJoined int64 = 3
    OpCodeError        int64 = 4
    OpCodeTurnTimer    int64 = 5
)
```

Note: Client→Server and Server→Client share opcode 1 for
MOVE / STATE_UPDATE. Direction is implicit (client sends,
server broadcasts).
