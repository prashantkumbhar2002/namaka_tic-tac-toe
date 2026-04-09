# OpCode Protocol Contract

**Transport**: Nakama real-time WebSocket (port 7350)
**Encoding**: JSON payloads in Nakama match data messages
**Tick rate**: 5 ticks/sec

## Client → Server

### OpCode 1: MOVE

Player submits a move during their turn.

```json
{
  "position": 4
}
```

| Field | Type | Constraints |
|-------|------|-------------|
| position | int | 0–8 inclusive (3×3 grid, row-major) |

**Server validation** (all must pass):
1. `match.Status == PLAYING`
2. `sender.UserId == match.CurrentTurn`
3. `match.Board[position] == ""`
4. `position >= 0 && position <= 8`

On failure → server sends OpCode 4 (ERROR) to sender only.
On success → server sends OpCode 1 (STATE_UPDATE) to all.

## Server → Client

### OpCode 1: STATE_UPDATE

Broadcast after every valid move.

```json
{
  "board": ["X","","O","","X","","","",""],
  "turn": "user-id-of-next-player",
  "status": "PLAYING"
}
```

| Field | Type | Notes |
|-------|------|-------|
| board | [9]string | Current board state |
| turn | string | userId whose turn is next |
| status | string | "WAITING", "PLAYING", or "FINISHED" |

### OpCode 2: GAME_OVER

Broadcast when game reaches terminal state.

```json
{
  "winner": "user-id-or-draw",
  "board": ["X","O","X","O","X","O","","","X"],
  "winning_line": [0, 4, 8]
}
```

| Field | Type | Notes |
|-------|------|-------|
| winner | string | userId of winner, `"draw"`, or `"forfeit"` |
| board | [9]string | Final board state |
| winning_line | [3]int | Indices of winning cells; `[-1,-1,-1]` on draw/forfeit |

### OpCode 3: PLAYER_JOINED

Sent to all presences when a player joins the match.

```json
{
  "player": "user-id",
  "symbol": "X",
  "opponent": {
    "user_id": "opponent-id",
    "display_name": "Player2",
    "symbol": "O"
  }
}
```

| Field | Type | Notes |
|-------|------|-------|
| player | string | userId of the joining player |
| symbol | string | "X" (first joiner) or "O" (second joiner) |
| opponent | object or null | Opponent info if both players present; null if waiting |

### OpCode 4: ERROR

Sent to the offending player only (never broadcast).

```json
{
  "code": "NOT_YOUR_TURN",
  "message": "It is not your turn"
}
```

| Code | Trigger |
|------|---------|
| `NOT_YOUR_TURN` | Player moved out of turn |
| `INVALID_CELL` | Cell already occupied or out of bounds |
| `GAME_OVER` | Move sent after game finished |
| `UNAUTHORIZED` | Guest attempted a registered-only action |

### OpCode 5: TURN_TIMER (Bonus — Timed Mode)

Broadcast each tick during timed mode.

```json
{
  "remaining_seconds": 22
}
```

| Field | Type | Notes |
|-------|------|-------|
| remaining_seconds | int | Seconds remaining for current turn; 0 triggers forfeit |
