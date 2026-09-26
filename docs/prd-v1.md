# Spotique — Product Requirements Document

**Version 1.0 · MVP · April 2026**

---

## 1. Product Overview

- **App name:** Spotique
- **Tagline:** "Not just a spot. The spot."
- **Platform:** iOS (Swift + SwiftUI) and Android (Kotlin + Jetpack Compose)
- **MVP geography:** Jackson Heights, Queens, NY 11372
- **Business model:** Free for hosts and drivers during MVP phase

### 1.1 Vision

Spotique makes private parking spots in Jackson Heights discoverable and bookable by the hour — connecting homeowners and condo residents who have underutilized driveways and garages with drivers seeking affordable, convenient parking near the neighborhood's commercial corridor.

### 1.2 Problem Statement

Jackson Heights has some of the most congested parking in Queens. The commercial strips along 37th Avenue, 74th Street, and Roosevelt Avenue draw visitors from across the borough, but the neighborhood has very few commercial parking facilities. Meanwhile, hundreds of private driveways and garages sit unused during peak hours. These two groups — drivers and hosts — have no mechanism to find each other. The informal market exists on Craigslist (monthly-only, no trust layer) and word of mouth. Spotique formalizes and makes it hourly.

### 1.3 Solution

A native mobile app where:

- Hosts (residents with driveways or garages) list their space with photos, hourly rate, and weekly availability
- Drivers browse available spots on a map, request bookings by time window, and receive the host's contact information after confirmation
- Payment happens off-platform in cash, Venmo, or Zelle — no in-app payment processing in MVP
- Both parties rate each other after each booking, building trust over time

---

## 2. Target Users

### 2.1 Host Persona — Maria, Jackson Heights Homeowner

- 45 years old, owns a 2-family brick home on 35th Avenue with a 1-car garage
- Garage sits empty most weekends; she'd like to earn extra income without much hassle
- Speaks Spanish primarily; comfortable with basic smartphone apps
- Concerned about strangers accessing her property — needs clear trust signals and control over who she accepts
- **Success for Maria:** earning $40–80 on a Saturday without leaving her house

### 2.2 Driver Persona — Raj, Weekend Visitor

- 32 years old, drives from Flushing to shop at Indian grocery stores on 74th Street
- Typically circles for 20–30 minutes looking for street parking before giving up
- Would pay $10–15/hour for a guaranteed spot within 5 minutes' walk
- Comfortable with apps — uses Uber and DoorDash regularly
- **Success for Raj:** confirmed spot before he leaves the house, zero circling

---

## 3. Goals & Success Metrics

### 3.1 North Star Metric

**Driver repeat booking rate** — the percentage of drivers who make a second booking within 30 days of their first. This is the clearest signal the product solved a real problem and built sufficient trust to return.

### 3.2 90-Day Pilot Targets

| Metric | Target | Rationale |
|--------|--------|-----------|
| Active host listings | 20+ | Minimum viable supply for Jackson Heights |
| Booking requests submitted | 50+ | Enough to validate driver demand |
| Request acceptance rate | ≥40% | Hosts responding and confirming bookings |
| Driver 30-day repeat rate | ≥30% | North star — indicates real value created |
| Average post-booking rating | ≥4.0 / 5.0 | Trust and quality baseline |
| Zero property damage incidents | 100% | Critical for host retention |

---

## 4. Feature Requirements

Features are tagged **P0** (required for launch), **P1** (important for v1.0 quality), or **P2** (post-MVP). No P2 items will be built in the initial release.

### 4.1 Authentication & Onboarding

#### P0 — Phone Number Verification

- User enters US mobile phone number
- App sends SMS verification code via Firebase Auth
- User enters 6-digit code to authenticate
- New users prompted to enter display name (first name + last initial only)
- New users select role: "I have a spot to rent" / "I need parking" / "Both"

**Acceptance criteria:**

- Phone verification restricted to US numbers (+1)
- Invalid codes show clear error; resend code available after 60 seconds
- Unauthenticated users cannot access any app screen beyond auth flow
- Role selection can be changed later in Settings

### 4.2 Host: Listing Creation

#### P0 — Create a Parking Spot Listing

**Required fields:**

- Street address (Google Places Autocomplete, restricted to zip code 11372)
- Spot type: Driveway or Garage
- Photos: 1–4 photos, minimum 1 required
- Hourly rate: whole dollars only, minimum $5, maximum $50
- Weekly availability schedule: per-day toggle (on/off) with start and end time
- Optional description (max 200 characters)
- Preferred payment method display text (e.g. "Cash or Venmo @hostname")

**Acceptance criteria:**

- Address field uses Google Places Autocomplete; GPS coordinates extracted and stored
- Photos compressed client-side before upload (max 800 KB per image, JPEG quality 0.7)
- Listing saved to Firestore as active immediately on creation
- Host sees their pin appear on the map within 30 seconds
- Duplicate listings at the same address are flagged with a warning (not blocked)

#### P0 — Manage Listing

- Toggle listing active / inactive with a single switch
- Edit any listing field
- Add or remove blocked dates (specific calendar dates when the spot is unavailable)
- Delete listing (requires confirmation dialog)

**Acceptance criteria:**

- Inactive listings disappear from the driver map within 10 seconds
- Deletion with active pending/confirmed bookings shows: "Are you sure? Pending bookings will be cancelled."

### 4.3 Host: Booking Management

#### P0 — Booking Inbox

- List of all pending booking requests, sorted by start time (soonest first)
- Each request card shows: driver display name, requested date/time, duration, calculated total
- Accept and Decline buttons per request
- Accepted bookings reveal driver's phone number to host

**Acceptance criteria:**

- Push notification sent to host within 5 seconds of new booking request
- Tapping notification deep-links to the specific request
- Accept → booking status becomes "confirmed"; driver notified immediately
- Decline → booking status becomes "cancelled"; driver notified immediately
- Host can optionally add a decline reason (free text, shown to driver)

#### P1 — Booking History

- Full list of all bookings (upcoming, past, cancelled) with filter tabs
- Tap any booking to see full detail: driver info, time, total, payment method used

### 4.4 Driver: Finding a Spot

#### P0 — Map View

- Google Maps centered on Jackson Heights (37th Ave / 74th St, zoom 15)
- Available spots shown as custom pin markers with spot type icon and hourly rate
- Driver can set a "When" filter: date + start time + duration — map updates to show only available spots for that window
- Tap a pin to open a spot preview card (photo, type, rate, distance from current location)
- Filter by spot type: Driveway / Garage / Both (default: Both)

**Acceptance criteria:**

- Map loads within 3 seconds on LTE connection
- Only active listings with availability covering the selected time window are shown
- When no "When" filter is set, all active listings are shown
- Minimum 44pt touch target on all pins and interactive elements

#### P0 — Spot Detail Screen

- Full-screen swipeable photo gallery
- Host display name and positive rating percentage
- Spot type, display address only ("35th Avenue, Jackson Heights" — not the house number)
- Hourly rate and calculated total for the requested duration
- Host's available hours for the selected day
- "Request Booking" button — disabled if a time conflict exists

**Acceptance criteria:**

- Full street address and house number hidden until booking is confirmed
- "Request Booking" disabled with explanation if the time window conflicts with an existing booking

#### P0 — Request Booking

- Driver selects date, start time, end time
- App calculates and displays total cost (rate × hours)
- Confirmation screen summarizes details and shows payment reminder: "You'll pay the host directly in cash, Venmo, or Zelle on arrival."

**Acceptance criteria:**

- Can only request future time slots
- Minimum booking duration: 1 hour; maximum: 8 hours
- Overlap check runs against all pending + confirmed bookings before submission
- On conflict: "This spot is already booked for that time. Please choose a different window."
- On success: Firestore booking created as "pending"; host push notification fired

### 4.5 Driver: Booking Confirmation & Contact

#### P0 — Booking Status & Contact

- "My Bookings" list shows all driver bookings with status badges: Pending / Confirmed / Cancelled / Completed
- After confirmation: full address revealed, host phone number shown, payment method shown
- Push notification sent on host accept or decline

**Acceptance criteria:**

- Address and host contact only visible to driver after status = confirmed
- Confirmed bookings show countdown: "Your booking starts in X hours"

### 4.6 Ratings

#### P1 — Post-Booking Rating

- 48 hours after booking end time, both host and driver receive a push notification: "How was your experience with [Name]?"
- Rating UI: thumbs up or thumbs down
- If thumbs down: multi-select issue tags displayed
- Optional private free-text note (internal use only, never displayed publicly)
- Rating window closes automatically after 48 hours

**Issue tags by party:**

| Party being rated | Available issue tags |
|-------------------|---------------------|
| Driver (rated by host) | `no_show`, `late_arrival`, `didnt_pay`, `left_mess`, `rude_behavior` |
| Host (rated by driver) | `spot_occupied`, `misrepresented`, `host_unreachable`, `access_blocked`, `rude_behavior`, `false_listing` |

**What is displayed publicly:**

- User profile: "94% positive · 17 bookings"
- Driver profile only: "No-shows: 0" (shown even when zero — zero is a positive trust signal)
- Specific negative tags are never shown publicly

#### P1 — No-Show Reporting

- 30 minutes after booking start time, if driver hasn't been marked as arrived, host sees prompt: "Driver hasn't shown up?"
- Tapping it marks booking `noShow: true` and auto-submits a negative rating with the `no_show` tag
- Driver receives notification that no-show was reported
- Thresholds: 3 no-shows → in-app warning; 5 no-shows → booking privileges suspended

### 4.7 Push Notifications

#### P0 — Required Notifications

| Trigger | Recipient | Message |
|---------|-----------|---------|
| New booking request received | Host | "[Name] wants to park Sat 2–5pm. Tap to respond." |
| Booking confirmed by host | Driver | "Booking confirmed! Tap to see full address and host contact." |
| Booking declined by host | Driver | "Your request was declined. Try another spot nearby." |
| Rating window opens (48h post-booking) | Both | "How was your experience with [Name]? Rate them now." |

#### P1 — Additional Notifications

| Trigger | Recipient | Message |
|---------|-----------|---------|
| 30 min after start, driver not arrived | Host | "Driver hasn't shown up? Tap to report a no-show." |
| 1 hour before booking start | Driver | "Your Spotique booking starts in 1 hour." |
| No-show reported by host | Driver | "[Host] reported you didn't arrive for your booking." |

### 4.8 Profile & Settings

#### P1 — User Profile

- Display name (editable)
- Rating summary (positive % + total booking count)
- No-show count (drivers only)
- Role toggle (Host / Driver / Both)
- Active listings section (hosts only)
- Booking history (all users)

#### P1 — Settings

- Push notification preferences (per notification type)
- Payment method display text (hosts — shown to drivers after confirmation)
- Log out
- Delete account (deletes Firestore user document and anonymizes booking records)

---

## 5. Out of Scope (MVP)

| Feature | Rationale for exclusion |
|---------|------------------------|
| In-app payments (Stripe Connect) | Adds significant complexity; off-platform payment sufficient to validate the model |
| In-app messaging / chat | Phone number exchange after confirmation is sufficient; reduces build scope significantly |
| Web version | Mobile-first; host recruitment happens door-to-door with smartphone demos |
| Expansion beyond Jackson Heights | Validate supply/demand fit in one micro-market before scaling |
| Monthly or long-term parking | Hourly parking validates the model faster and is the acute pain point |
| Commercial parking lots | Private residential supply is the differentiated product; garages are already on SpotHero |
| Dynamic or surge pricing | Fixed host-set rates reduce friction and trust barriers during MVP |
| EV charging integration | Future premium tier; requires host hardware verification |
| Referral or invite program | Build after product-market fit is confirmed |
| Earnings dashboard for hosts | Off-platform payment means no app-side transaction data in MVP |
| Spanish localization | P1 post-launch; critical for JH host recruitment at scale but not a launch blocker |

---

## 6. User Flows

### 6.1 Host Onboarding & Listing Flow

1. Download app → Enter phone number → Verify SMS code → Enter display name → Select role (Host) → Create listing CTA
2. Listing wizard: Address → Spot type → Photos → Hourly rate → Availability schedule → Description (optional) → Payment info → Preview → Publish
3. Listing live: host sees their pin on the map; inbox tab shows 0 pending requests

### 6.2 Driver Booking Flow

1. Download app → Phone verification → Display name → Select role (Driver) → Map shown centered on Jackson Heights
2. Set "When" filter (date + start + end time) → Map updates → Browse available pins → Tap pin → Spot detail
3. Request booking → Confirm details + payment reminder → Submit request (status: Pending)
4. Await host response → Push notification: Confirmed or Declined
5. If confirmed: full address + host contact revealed → Meet host → Pay directly → Park

### 6.3 Post-Booking Rating Flow

1. 48 hours after booking end → Push notification to both parties
2. Tap notification → Rating screen → Thumbs up or down
3. If thumbs down → Issue tag selection (multi-select) → Optional note
4. Submit → User stats updated atomically in Firestore → Rating visible on profile

---

## 7. Non-Functional Requirements

### 7.1 Performance

- Map loads within 3 seconds on LTE connection (iPhone 12 / Pixel 5 or newer)
- App cold launch within 3 seconds on supported minimum device
- Booking request submission completes within 2 seconds
- Push notifications delivered within 5 seconds of Firestore trigger

### 7.2 Security & Privacy

- Firebase Authentication with phone number verification required for all access
- Firestore Security Rules enforce users can only read/write their own data
- Full listing address hidden in map view and spot detail; revealed only after booking confirmation
- Host phone number revealed only to confirmed drivers; driver phone revealed only to host after booking creation
- No third-party analytics SDK that shares user data during MVP
- Google Maps and Places API keys restricted to app bundle IDs

### 7.3 Accessibility

- VoiceOver (iOS) and TalkBack (Android) support for all interactive elements
- Minimum 44×44pt touch targets on all tappable elements
- Color contrast ratio ≥4.5:1 for all body text; ≥3:1 for large text and UI components
- No information conveyed by color alone (always paired with icon or text label)

### 7.4 Offline Behavior

- Previously loaded map data and user's own listings and bookings are shown from cache when offline
- Booking submission requires active connection; a clear offline error is shown
- Photos cached locally for recently viewed spots

---

## 8. Open Questions

| # | Question | Decision needed by |
|---|----------|-------------------|
| 1 | Should hosts be required to add a profile photo, or is a display name + phone verification sufficient for trust? | Before design complete |
| 2 | What happens if a host never responds to a booking request? Auto-decline after 24 hours? | Before build starts |
| 3 | Should a driver be able to book the same spot for multiple consecutive days? | Before booking request screen design |
| 4 | Should we allow a host to have more than one active listing (e.g. both a driveway and a garage)? | Before listing creation build |
| 5 | What is the grace period for a driver to cancel a confirmed booking without it counting against them? | Before ratings build |
