# Skill: Firebase Sync

Ensure Firebase configuration and data models are consistent across all platforms.

## Before You Start

1. Read `CLAUDE.md` for the overall project context.
2. Read `docs/api-contract.md` for the canonical data shapes.
3. Review Firebase config in each platform directory.

## Checklist

### Data Models

Verify these collections have consistent field names, types, and validation across iOS, Android, and the Rails API:

- **users** — `id`, `phone`, `display_name`, `created_at`
- **listings** — `id`, `host_id`, `address`, `latitude`, `longitude`, `spot_type`, `hourly_rate_cents`, `description`, `available_from`, `available_to`, `photos`, `rating_avg`, `rating_count`
- **bookings** — `id`, `listing_id`, `driver_id`, `host_id`, `status`, `start_time`, `end_time`, `total_cents`, `created_at`
- **ratings** — `id`, `booking_id`, `rater_id`, `score`, `no_show`, `created_at`

### Firestore Security Rules

- Users can only read/write their own profile.
- Listings: anyone authenticated can read; only the host can write.
- Bookings: only the driver and host involved can read; driver creates, host updates status.
- Ratings: only the rater can create; both parties can read.
- Address field on listings: only readable by users with a confirmed booking (enforce in rules or API layer).

### Auth Flows

- All platforms use Firebase Phone Auth with SMS verification.
- The Rails API verifies Firebase ID tokens (not session cookies).
- Token refresh is handled client-side; the API rejects expired tokens with 401.

### Push Notifications

- **iOS**: APNs via Firebase Cloud Messaging. Ensure APNs key is uploaded to Firebase Console.
- **Android**: FCM directly. Ensure `google-services.json` is in the app module.
- **Triggers**: New booking request → notify host. Accept/decline → notify driver. Rating window open → notify both.

## Output

After running this skill, report:
1. Any field name mismatches across platforms.
2. Any missing security rules.
3. Any auth flow inconsistencies.
4. Push notification setup gaps.
