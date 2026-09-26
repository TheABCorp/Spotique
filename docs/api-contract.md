# Spotique API Contract v1

Base URL: `/api/v1`

All authenticated endpoints require header: `Authorization: Bearer <firebase_id_token>`

---

## Authentication

### `POST /auth/verify`

Verify a Firebase phone-auth ID token and return/create the user profile.

**Request:**
```json
{ "id_token": "eyJhbG..." }
```

**Response (200):**
```json
{
  "data": {
    "id": "uid_abc123",
    "phone": "+13475551234",
    "display_name": "Jane",
    "created_at": "2025-01-15T10:00:00Z"
  }
}
```

---

## Listings

### `GET /listings`

List available parking spots. Supports geo-filtering.

**Query params:**
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `lat` | float | yes | Latitude center |
| `lng` | float | yes | Longitude center |
| `radius_mi` | float | no | Search radius in miles (default: 0.5) |
| `available_from` | ISO 8601 | no | Filter by availability start |
| `available_to` | ISO 8601 | no | Filter by availability end |
| `page` | int | no | Page number (default: 1) |
| `per_page` | int | no | Results per page (default: 20, max: 50) |

**Response (200):**
```json
{
  "data": [
    {
      "id": "listing_123",
      "host_id": "uid_abc123",
      "host_display_name": "Jane",
      "latitude": 40.7496,
      "longitude": -73.8783,
      "neighborhood": "Jackson Heights",
      "spot_type": "driveway",
      "hourly_rate_cents": 500,
      "description": "Covered driveway, fits SUV",
      "available_from": "2025-06-01T08:00:00Z",
      "available_to": "2025-06-01T18:00:00Z",
      "photos": ["https://..."],
      "rating_avg": 4.5,
      "rating_count": 12
    }
  ],
  "meta": {
    "pagination": { "page": 1, "per_page": 20, "total": 42 }
  }
}
```

**Note:** Full street address is NOT returned in listing list/detail. It is only revealed after a booking is confirmed.

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
    "available_from": "2025-06-01T08:00:00Z",
    "available_to": "2025-06-01T18:00:00Z"
  }
}
```

**Response (201):** Returns the created listing object.

### `GET /listings/:id`

Get listing details. Address is redacted unless the caller has a confirmed booking.

**Response (200):** Single listing object (same shape as list items, plus `address` if authorized).

### `PATCH /listings/:id`

Update a listing. Host only.

### `DELETE /listings/:id`

Remove a listing. Host only.

---

## Bookings

### `POST /bookings`

Request a booking (driver only).

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
    "created_at": "2025-05-28T12:00:00Z"
  }
}
```

### `PATCH /bookings/:id`

Accept or decline a booking (host only).

**Request:**
```json
{ "booking": { "status": "confirmed" } }
```

Valid status transitions: `pending` → `confirmed` | `declined`

**On confirm:** Response includes the full address and host phone number.

### `GET /bookings`

List the current user's bookings (as host or driver).

**Query params:**
| Param | Type | Description |
|-------|------|-------------|
| `role` | string | `host` or `driver` (default: both) |
| `status` | string | Filter by status |
| `page` | int | Page number |

---

## Ratings

### `POST /ratings`

Submit a post-booking rating (thumbs up/down). Both host and driver can rate.

**Request:**
```json
{
  "rating": {
    "booking_id": "booking_456",
    "score": 1,
    "no_show": false
  }
}
```

`score`: `1` (thumbs up) or `-1` (thumbs down).
`no_show`: `true` if the other party didn't show up.

**Response (201):** Returns the created rating.

### `GET /ratings`

Get ratings for a user.

**Query params:** `user_id` (required), `page`, `per_page`

---

## Enums

| Field | Values |
|-------|--------|
| `spot_type` | `driveway`, `garage`, `street`, `lot` |
| `booking.status` | `pending`, `confirmed`, `declined`, `completed`, `cancelled` |
| `rating.score` | `1` (thumbs up), `-1` (thumbs down) |

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
