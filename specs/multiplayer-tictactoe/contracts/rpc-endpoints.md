# RPC Endpoint Contracts

**Transport**: Nakama HTTP REST (port 7350)
**Auth**: JWT bearer token (from nakama-js session)
**Base path**: `/v2/rpc/<rpc_name>`

## create_room

**Auth requirement**: Registered users only. Guests receive 403.

Creates a new server-authoritative match and returns a room code
for sharing.

### Request

```
POST /v2/rpc/create_room
Authorization: Bearer <jwt>
Content-Type: application/json

{
  "mode": "classic"
}
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| mode | string | No | "classic" (default) or "timed" |

### Response (200)

```json
{
  "match_id": "b3f5a8c2-1234-5678-9abc-def012345678",
  "room_code": "b3f5a8c2"
}
```

### Errors

| Code | Condition |
|------|-----------|
| 403 | Caller is a guest (not registered) |
| 500 | Match creation failed |

### Server-side flow

1. Check `isRegisteredUser(ctx, nk, userId)` → reject if false
2. `nk.MatchCreate(ctx, "tictactoe", params)`
3. Extract room code: `matchId[:8]`
4. `nk.StorageWrite(ctx, [{collection: "room_codes", key: roomCode, value: {match_id: matchId}}])`
5. Return `{match_id, room_code}`

---

## join_room

**Auth requirement**: Registered users only. Guests receive 403.

Looks up a room code and returns the match ID for WebSocket join.

### Request

```
POST /v2/rpc/join_room
Authorization: Bearer <jwt>
Content-Type: application/json

{
  "room_code": "b3f5a8c2"
}
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| room_code | string | Yes | 8-character room code |

### Response (200)

```json
{
  "match_id": "b3f5a8c2-1234-5678-9abc-def012345678"
}
```

### Errors

| Code | Condition |
|------|-----------|
| 403 | Caller is a guest (not registered) |
| 404 | Room code not found or match expired |
| 400 | Missing or invalid room_code field |

### Server-side flow

1. Check `isRegisteredUser(ctx, nk, userId)` → reject if false
2. `nk.StorageRead(ctx, [{collection: "room_codes", key: roomCode, userId: systemUserId}])`
3. If not found → 404
4. Extract `match_id` from stored value
5. Return `{match_id}`

Client then joins via WebSocket: `socket.joinMatch(matchId)`

---

## get_leaderboard

**Auth requirement**: Registered users only. Guests receive 403.

Returns the global top-10 leaderboard entries sorted by total
wins descending.

### Request

```
POST /v2/rpc/get_leaderboard
Authorization: Bearer <jwt>
Content-Type: application/json

{}
```

No request body fields required.

### Response (200)

```json
{
  "records": [
    {
      "rank": 1,
      "owner_id": "user-uuid",
      "username": "PlayerOne",
      "score": 42,
      "subscore": 7,
      "metadata": "{\"last_opponent\":\"user-uuid-2\"}"
    }
  ]
}
```

| Field | Type | Notes |
|-------|------|-------|
| rank | int | 1-indexed position |
| owner_id | string | Player's user ID |
| username | string | Display name |
| score | int64 | Total wins |
| subscore | int64 | Current win streak |
| metadata | string | JSON string with extra data |

### Server-side flow

1. Check `isRegisteredUser(ctx, nk, userId)` → reject if false
2. `nk.LeaderboardRecordsList(ctx, "tictactoe_wins", []string{}, 10, "", 0)`
3. Map records to response format
4. Return `{records}`

---

## get_player_stats

**Auth requirement**: Registered users only. Guests receive 403.

Returns the requesting player's own leaderboard record.

### Request

```
POST /v2/rpc/get_player_stats
Authorization: Bearer <jwt>
Content-Type: application/json

{}
```

### Response (200)

```json
{
  "rank": 5,
  "wins": 12,
  "win_streak": 3
}
```

### Response (200 — no record)

```json
{
  "rank": 0,
  "wins": 0,
  "win_streak": 0
}
```

### Server-side flow

1. Check `isRegisteredUser(ctx, nk, userId)` → reject if false
2. `nk.LeaderboardRecordsList(ctx, "tictactoe_wins", []string{userId}, 1, "", 0)`
3. If record exists → map to response
4. If no record → return zeroed stats
