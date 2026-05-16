import Foundation

// Mirrors apps/web/src/types/api.ts. Server returns camelCase JSON with
// .NET-style ISO 8601 timestamps including 7-digit fractional seconds and
// "+00:00" offsets, e.g. "2026-05-16T08:25:50.2578890+00:00". JSONDecoder
// in ApiClient.swift handles both .withFractionalSeconds and the plain form.

// MARK: - Search lifecycle

struct CreateSearchRequest: Codable {
    var title: String
    var centerLng: Double?
    var centerLat: Double?
    var zoom: Int?
}

struct CreateSearchResponse: Codable {
    var slug: String
    var ownerToken: String
    var joinUrl: String
}

struct JoinRequest: Codable {
    var displayName: String
}

struct JoinResponse: Codable {
    var participantId: UUID
    var sessionToken: String
    var color: String
}

// MARK: - GeoJSON geometries

// We model just the three GeoJSON kinds the API uses. The `type` field is
// kept as a stored property (with default) so encoding always emits it.

struct PointGeometry: Codable, Equatable {
    var type: String = "Point"
    var coordinates: [Double]  // [lng, lat]

    var lng: Double { coordinates[0] }
    var lat: Double { coordinates[1] }

    init(lng: Double, lat: Double) {
        self.coordinates = [lng, lat]
    }
}

struct PolygonGeometry: Codable, Equatable {
    var type: String = "Polygon"
    var coordinates: [[[Double]]]  // rings → [lng, lat]

    init(ring: [[Double]]) {
        self.coordinates = [ring]
    }

    init(coordinates: [[[Double]]]) {
        self.coordinates = coordinates
    }
}

struct LineStringGeometry: Codable, Equatable {
    var type: String = "LineString"
    var coordinates: [[Double]]  // [lng, lat] points
}

// MARK: - Snapshot DTOs

struct ParticipantDto: Codable, Identifiable, Equatable {
    var id: UUID
    var displayName: String
    var color: String
    var joinedAt: Date
    var lastSeenAt: Date
    var lastPosition: PointGeometry?
}

struct AreaDto: Codable, Identifiable, Equatable {
    var id: UUID
    var createdByParticipantId: UUID
    var createdAt: Date
    var geometry: PolygonGeometry
    var title: String?
    var color: String?
}

struct PathDto: Codable, Identifiable, Equatable {
    var id: UUID
    var participantId: UUID
    var startedAt: Date
    var endedAt: Date?
    var geometry: LineStringGeometry
}

struct SearchSnapshotDto: Codable {
    var slug: String
    var title: String
    var createdAt: Date
    var expiresAt: Date?
    var center: PointGeometry?
    var defaultZoom: Int
    var participants: [ParticipantDto]
    var areas: [AreaDto]
    var paths: [PathDto]
}

// MARK: - Hub events

struct PositionUpdateDto: Codable, Equatable {
    var participantId: UUID
    var lng: Double
    var lat: Double
    var accuracyMeters: Double
    var headingDegrees: Double?
    var recordedAt: Date
}

struct SearchUpdatedDto: Codable {
    var title: String
    var expiresAt: Date?
}

// MARK: - Area / path requests

struct AddAreaRequest: Codable {
    var geometry: PolygonGeometry
    var title: String?
    var color: String?
}

struct StartPathRequest: Codable {
    var points: [[Double]]
}

struct UpdatePathRequest: Codable {
    var points: [[Double]]?
    var finalize: Bool?
}

// MARK: - Manage (owner-only)

struct UpdateSearchRequest: Codable {
    var title: String?
    var expiresAt: Date?
}

struct UpdateSearchResponse: Codable {
    var title: String
    var expiresAt: Date?
}

struct ClearPathsResponse: Codable {
    var cleared: Int
}
