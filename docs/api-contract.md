# Spotique API Contract v1

Base URL: `/api/v1`

All authenticated endpoints require header: `Authorization: Bearer <firebase_id_token>`

Source of truth for product requirements: [`prd-v1.md`](prd-v1.md)

---

## Authentication

### `POST /auth/verify`

Verify a Firebase phone-auth ID token and return/create the user profile.

**Request:**
```json
{
  "id_token": "eyJhbG...",
  "display_name": "Jane D",
  "role": "host"
}
```

`display_name` and `role` are required only on first verification (new user creation).

**Response (200):**
```json
{
  "data": {
    "id": "uid_abc123",
    "phone": "+13475551234",
    "display_name": "Jane D",
    "role": "host",
    "rating_positive_pct": null,
    "rating_count": 0,
    "no_show_count": 0,
    "created_at": "2025-01-15T10:00:00Z"
  }
}
```

### `PATCH /users/me`

Update current user's profile. Requires authentication.

**Request:**
```json
{
  "user": {
    "display_name": "Jane D",
    "role": "both",
    "payment_method_text": "Cash or Venmo @janed"
  }
}
```

**Response (200):** Returns the updated user object.

### `DELETE /users/me`

Delete account. Deletes Firestore user document and anonymizes booking records (PRD §4.8).

**Response (204):** No content.

---

## Listings

### `GET /listings`

List available parking spots. Supports geo-filtering and time-window filtering (PRD §4.4 Map View).

**Query params:**
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `lat` | float | yes | Latitude center |
| `lng` | float | yes | Longitude center |
| `radius_mi` | float | no | Search radius in miles (default: 0.5) |
| `available_from` | ISO 8601 | no | Filter by availability window start |
| `available_to` | ISO 8601 | no | Filter by availability window end |
| `spot_type` | string | no | `driveway`, `garage`, or omit for both |
| `page` | int | no | Page number (default: 1) |
| `per_page` | int | no | Results per page (default: 20, max: 50) |

**Response (200):**
```json
{
  "data": [
    {
      "id": "listing_123",
      "host_id": "uid_abc123",
      "host_display_name": "Jane D",
      "host_rating_positive_pct": 94,
      "host_rating_count": 17,
      "latitude": 40.7496,
      "longitude": -73.8783,
      "display_address": "35th Avenue, Jackson Heights",
      "spot_type": "driveway",
      "hourly_rate_cents": 500,
      "description": "Covered driveway, fits SUV",
      "photos": ["https://..."],
      "availability_schedule": {
        "monday": { "enabled": true, "start": "08:00", "end": "18:00" },
        "tuesday": { "enabled": false },
        "wednesday": { "enabled": true, "start": "08:00", "end": "18:00" }
      },
      "blocked_dates": ["2025-06-15", "2025-06-16"],
      "payment_method_text": "Cash or Venmo @janed",
      "active": true,
      "created_at": "2025-05-01T10:00:00Z"
    }
  ],
  "meta": {
    "pagination": { "page": 1, "per_page": 20, "total": 42 }
  }
}
```

**Privacy:** `display_address` shows street name only (e.g. "35th Avenue, Jackson Heights") — never the house number. Full address is only returned in confirmed booking responses (PRD §7.2).

### `POST /listings`

Create a new listing (host only). Requires authentication.

**Request:**
```json
{
  "listing": {
    "address": "34-15 74th Street, Jackson Heights, NY 11372",
    "latitude": 40.7496,
    "longitude": -73.8783,
    "spot_type": "driveway",
    "hourly_rate_cents": 500,
    "description": "Covered driveway, fits SUV",
    "photos": ["<upload_url_or_base64>"],
    "availability_schedule": {
      "monday": { "enabled": true, "start": "08:00", "end": "18:00" },
      "tuesday": { "enabled": false }
    },
    "payment_method_text": "Cash or Venmo @janed"
  }
}
```

**Validations (PRD §4.2):**
- `address`: Must be in zip code 11372. Duplicate address triggers a warning (not a block).
- `spot_type`: `driveway` or `garage` only.
- `photos`: 1–4 required. Client compresses to max 800 KB JPEG quality 0.7 before upload.
- `hourly_rate_cents`: Whole dollars only ($5–$50 → 500–5000 cents).
- `description`: Max 200 characters. Optional.
- `availability_schedule`: At least one day enabled.

**Response (201):** Returns the created listing object.

### `GET /listings/:id`

Get listing details. Address is redacted to `display_address` unless the caller has a confirmed booking for this listing.

**Response (200):** Single listing object. Includes `address` field only if caller has a confirmed booking.

### `PATCH /listings/:id`

Update a listing. Host only. Accepts any subset of listing fields.

**Response (200):** Returns the updated listing object.

### `PATCH /listings/:id/toggle`

Toggle listing active/inactive. Host only. Convenience endpoint for the active/inactive switch (PRD §4.2).

**Request:**
```json
{ "active": false }
```

**Response (200):** Returns the updated listing object.

### `DELETE /listings/:id`

Remove a listing. Host only. If the listing has pending or confirmed bookings, they are cancelled and the drivers are notified (PRD §4.2).

**Response (204):** No content.

---

## Bookings

### `POST /bookings`

Request a booking (driver only). Server validates time overlap against all pending + confirmed bookings for this listing (PRD §4.4).

**Request:**
```json
{
  "booking": {
    "listing_id": "listing_123",
    "start_time": "2025-06-01T10:00:00Z",
    "end_time": "2025-06-01T14:00:00Z"
  }
}
```

**Validations (PRD §4.4):**
- `start_time` must be in the future.
- Duration: minimum 1 hour, maximum 8 hours.
- No overlap with existing pending or confirmed bookings for this listing.
- On conflict: returns 409 with error `"booking_conflict"`.

**Response (201):**
```json
{
  "data": {
    "id": "booking_456",
    "listing_id": "listing_123",
    "driver_id": "uid_xyz789",
    "host_id": "uid_abc123",
    "status": "pending",
    "start_time": "2025-06-01T10:00:00Z",
    "end_time": "2025-06-01T14:00:00Z",
    "total_cents": 2000,
    "no_show": false,
    "decline_reason": null,
    "created_at": "2025-05-28T12:00:00Z"
  }
}
```

**Side effect:** Push notification sent to host (PRD §4.7).

### `PATCH /bookings/:id`

Accept or decline a booking (host only).

**Request (accept):**
```json
{ "booking": { "status": "confirmed" } }
```

**Request (decline):**
```json
{ "booking": { "status": "declined", "decline_reason": "Away that weekend" } }
```

`decline_reason` is optional free text shown to the driver (PRD §4.3).

**Valid status transitions:**
- `pending` → `confirmed` | `declined`
- `confirmed` → `completed` | `cancelled`

**On confirm response** includes additional fields:
```json
{
  "data": {
    "...booking fields...",
    "status": "confirmed",
    "address": "34-15 74th Street, Jackson Heights, NY 11372",
    "host_phone": "+13475551234",
    "driver_phone": "+17185559876",
    "payment_method_text": "Cash or Venmo @janed"
  }
}
```

**Side effects:**
- Confirm → push notification to driver with address (PRD §4.7)
- Decline → push notification to driver (PRD §4.7)
- Host receives driver's phone number on booking creation; driver receives host's phone on confirmation (PRD §7.2)

### `POST /bookings/:id/no_show`

Host reports driver as a no-show. Available 30 minutes after `start_time` (PRD §4.6).

**Request:** Empty body.

**Response (200):**
```json
{
  "data": {
    "...booking fields...",
    "no_show": true
  }
}
```

**Side effects:**
- Auto-creates a negative rating with `no_show` tag for the driver.
- Push notification sent to driver (PRD §4.7).
- Driver's `no_show_count` incremented. At 3 → warning; at 5 → booking privileges suspended.

### `GET /bookings`

List the current user's bookings (as host or driver).

**Query params:**
| Param | Type | Description |
|-------|------|-------------|
| `role` | string | `host` or `driver` (default: both) |
| `status` | string | Filter: `pending`, `confirmed`, `declined`, `completed`, `cancelled` |
| `page` | int | Page number (default: 1) |
| `per_page` | int | Results per page (default: 20) |

**Response (200):**
```json
{
  "data": ["...array of booking objects..."],
  "meta": {
    "pagination": { "page": 1, "per_page": 20, "total": 8 }
  }
}
```

Confirmed bookings include `address`, `host_phone`/`driver_phone`, and `payment_method_text`. Other statuses redact those fields.

---

## Ratings

### `POST /ratings`

Submit a post-booking rating. Both host and driver can rate each other. Rating window: 48 hours after booking `end_time` (PRD §4.6).

**Request:**
```json
{
  "rating": {
    "booking_id": "booking_456",
    "score": 1,
    "tags": [],
    "note": ""
  }
}
```

- `score`: `1` (thumbs up) or `-1` (thumbs down).
- `tags`: Array of issue tag strings. Only allowed when `score` is `-1`.
- `note`: Optional private free-text note (never displayed publicly, internal use only).

**Driver issue tags** (when host rates driver): `no_show`, `late_arrival`, `didnt_pay`, `left_mess`, `rude_behavior`

**Host issue tags** (when driver rates host): `spot_occupied`, `misrepresented`, `host_unreachable`, `access_blocked`, `rude_behavior`, `false_listing`

**Validations:**
- Caller must be the host or driver on the booking.
- Booking status must be `completed` or `confirmed` (with `end_time` in the past).
- Rating window: within 48 hours of `end_time`. After that, returns 403 `"rating_window_closed"`.
- Each party can only rate once per booking.

**Response (201):** Returns the created rating object.

**Side effect:** User's `rating_positive_pct` and `rating_count` updated atomically.

### `GET /users/:id/ratings`

Get public rating summary for a user.

**Response (200):**
```json
{
  "data": {
    "user_id": "uid_abc123",
    "positive_pct": 94,
    "rating_count": 17,
    "no_show_count": 0
  }
}
```

**Note:** Specific negative tags are never returned publicly (PRD §4.6). Only aggregated stats are shown.

---

## Enums

| Field | Values |
|-------|--------|
| `spot_type` | `driveway`, `garage` |
| `booking.status` | `pending`, `confirmed`, `declined`, `completed`, `cancelled` |
| `rating.score` | `1` (thumbs up), `-1` (thumbs down) |
| `user.role` | `host`, `driver`, `both` |
| `rating.tags` (driver) | `no_show`, `late_arrival`, `didnt_pay`, `left_mess`, `rude_behavior` |
| `rating.tags` (host) | `spot_occupied`, `misrepresented`, `host_unreachable`, `access_blocked`, `rude_behavior`, `false_listing` |

**Note:** PRD §4.2 specifies spot types as "Driveway or Garage" only. `street` and `lot` from the previous contract version have been removed.

## Error Format

All errors return:
```json
{
  "error": {
    "code": "validation_failed",
    "message": "Human-readable message",
    "details": { "field": ["is required"] }
  }
}
```

**Standard error codes:**
| Code | HTTP Status | Description |
|------|-------------|-------------|
| `validation_failed` | 422 | Request body failed validation |
| `unauthorized` | 401 | Missing or invalid Firebase ID token |
| `forbidden` | 403 | Authenticated but not allowed (wrong role, not owner, etc.) |
| `not_found` | 404 | Resource does not exist |
| `booking_conflict` | 409 | Time window overlaps an existing booking |
| `rating_window_closed` | 403 | 48-hour rating window has expired |
