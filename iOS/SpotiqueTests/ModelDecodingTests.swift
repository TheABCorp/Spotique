import Testing
import Foundation
@testable import Spotique

struct ModelDecodingTests {
    @Test func decodesUser() throws {
        let json = """
        {"id":"uid_abc123","phone":"+13475551234","email":null,"first_name":"Jane","last_name":"Doe","address":"34-15 74th Street","role":"host","rating_positive_pct":94,"rating_count":17,"no_show_count":0,"created_at":"2025-01-15T10:00:00Z"}
        """.data(using: .utf8)!

        let user = try JSONCoding.decoder.decode(User.self, from: json)
        #expect(user.id == "uid_abc123")
        #expect(user.firstName == "Jane")
        #expect(user.role == .host)
        #expect(user.isHost == true)
        #expect(user.isDriver == false)
        #expect(user.displayName == "Jane D")
    }

    @Test func decodesListingWithAvailabilitySchedule() throws {
        let json = """
        {"id":"listing_123","host_id":"uid_abc123","latitude":40.7496,"longitude":-73.8783,"spot_type":"driveway","hourly_rate_cents":500,"photos":[],"active":true,"created_at":"2025-05-01T10:00:00Z","availability_schedule":{"monday":{"enabled":true,"start":"08:00","end":"18:00"},"tuesday":{"enabled":false}}}
        """.data(using: .utf8)!

        let listing = try JSONCoding.decoder.decode(Listing.self, from: json)
        #expect(listing.id == "listing_123")
        #expect(listing.spotType == .driveway)
        #expect(listing.hourlyRateCents == 500)
        #expect(listing.address == nil)
        let monday = listing.availabilitySchedule?[.monday]
        #expect(monday?.enabled == true)
        #expect(monday?.start == "08:00")
        let tuesday = listing.availabilitySchedule?[.tuesday]
        #expect(tuesday?.enabled == false)
        #expect(tuesday?.start == nil)
    }

    @Test func decodesBookingPending() throws {
        let json = """
        {"id":"booking_456","listing_id":"listing_123","driver_id":"uid_xyz789","host_id":"uid_abc123","status":"pending","start_time":"2025-06-01T10:00:00Z","end_time":"2025-06-01T14:00:00Z","total_cents":2000,"no_show":false,"decline_reason":null,"created_at":"2025-05-28T12:00:00Z"}
        """.data(using: .utf8)!

        let booking = try JSONCoding.decoder.decode(Booking.self, from: json)
        #expect(booking.id == "booking_456")
        #expect(booking.status == .pending)
        #expect(booking.totalCents == 2000)
        #expect(booking.address == nil)
        #expect(booking.hostPhone == nil)
        #expect(booking.driverPhone == nil)
    }

    @Test func decodesBookingConfirmedWithHiddenFields() throws {
        let json = """
        {"id":"booking_456","listing_id":"listing_123","driver_id":"uid_xyz789","host_id":"uid_abc123","status":"confirmed","start_time":"2025-06-01T10:00:00Z","end_time":"2025-06-01T14:00:00Z","total_cents":2000,"no_show":false,"decline_reason":null,"created_at":"2025-05-28T12:00:00Z","address":"34-15 74th Street","host_phone":"+13475551234","driver_phone":"+17185559876","payment_method_text":"Cash or Venmo @janed"}
        """.data(using: .utf8)!

        let booking = try JSONCoding.decoder.decode(Booking.self, from: json)
        #expect(booking.status == .confirmed)
        #expect(booking.address == "34-15 74th Street")
        #expect(booking.hostPhone == "+13475551234")
        #expect(booking.driverPhone == "+17185559876")
        #expect(booking.paymentMethodText == "Cash or Venmo @janed")
    }

    @Test func decodesRating() throws {
        let json = """
        {"id":"rating_1","booking_id":"booking_456","score":1,"tags":[],"note":null,"created_at":"2025-06-02T10:00:00Z"}
        """.data(using: .utf8)!

        let rating = try JSONCoding.decoder.decode(Rating.self, from: json)
        #expect(rating.score == .up)
        #expect(rating.tags.isEmpty)
    }

    @Test func unknownEnumValuesFallback() throws {
        let roleJSON = "\"superuser\"".data(using: .utf8)!
        let role = try JSONCoding.decoder.decode(UserRole.self, from: roleJSON)
        #expect(role == .driver)

        let statusJSON = "\"archived\"".data(using: .utf8)!
        let status = try JSONCoding.decoder.decode(BookingStatus.self, from: statusJSON)
        #expect(status == .unknown)
    }

    @Test func decodesFractionalSecondsDate() throws {
        let json = """
        {"id":"uid_1","phone":null,"email":null,"first_name":"A","last_name":"B","role":"driver","created_at":"2025-01-15T10:00:00.123Z"}
        """.data(using: .utf8)!

        let user = try JSONCoding.decoder.decode(User.self, from: json)
        #expect(user.id == "uid_1")
    }

    @Test func decodesVerifyResultExisting() throws {
        let json = """
        {"id":"uid_abc123","token":"eyJ","is_new":false,"user":{"id":"uid_abc123","phone":"+13475551234","email":null,"first_name":"Jane","last_name":"Doe","role":"host","created_at":"2025-01-15T10:00:00Z"}}
        """.data(using: .utf8)!

        let result = try JSONCoding.decoder.decode(VerifyResult.self, from: json)
        #expect(result.isNew == false)
        #expect(result.user?.firstName == "Jane")
    }

    @Test func decodesVerifyResultNew() throws {
        let json = """
        {"id":"uid_abc123","token":"eyJ","is_new":true,"user":null}
        """.data(using: .utf8)!

        let result = try JSONCoding.decoder.decode(VerifyResult.self, from: json)
        #expect(result.isNew == true)
        #expect(result.user == nil)
    }
}
