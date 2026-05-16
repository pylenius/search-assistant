import Foundation

enum ApiError: Error, CustomStringConvertible {
    case invalidResponse
    case status(Int, Data?)
    case decoding(Error)
    case network(Error)

    var description: String {
        switch self {
        case .invalidResponse: return "Invalid HTTP response"
        case .status(let code, _): return "HTTP \(code)"
        case .decoding(let e): return "Decode failed: \(e)"
        case .network(let e): return "Network: \(e.localizedDescription)"
        }
    }
}

struct ApiClient {
    static let shared = ApiClient(baseURL: AppConfig.apiBaseURL)

    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Search lifecycle

    func createSearch(_ body: CreateSearchRequest) async throws -> CreateSearchResponse {
        try await request(.post, "/api/searches", body: body)
    }

    func getSearch(slug: String) async throws -> SearchSnapshotDto {
        try await request(.get, "/api/searches/\(slug)")
    }

    func joinSearch(slug: String, displayName: String) async throws -> JoinResponse {
        try await request(.post, "/api/searches/\(slug)/join",
                          body: JoinRequest(displayName: displayName))
    }

    func me(slug: String, sessionToken: String) async throws -> ParticipantDto {
        try await request(.get, "/api/searches/\(slug)/me",
                          sessionToken: sessionToken)
    }

    // MARK: - Areas / paths (participant-authed)

    func addArea(slug: String,
                 geometry: PolygonGeometry,
                 title: String?,
                 color: String?,
                 sessionToken: String) async throws -> AreaDto {
        try await request(.post, "/api/searches/\(slug)/areas",
                          body: AddAreaRequest(geometry: geometry, title: title, color: color),
                          sessionToken: sessionToken)
    }

    func removeArea(slug: String,
                    areaId: UUID,
                    sessionToken: String) async throws {
        try await requestVoid(.delete, "/api/searches/\(slug)/areas/\(areaId.uuidString.lowercased())",
                              sessionToken: sessionToken)
    }

    func startPath(slug: String,
                   points: [[Double]],
                   sessionToken: String) async throws -> PathDto {
        try await request(.post, "/api/searches/\(slug)/paths",
                          body: StartPathRequest(points: points),
                          sessionToken: sessionToken)
    }

    func appendToPath(slug: String,
                      pathId: UUID,
                      points: [[Double]],
                      sessionToken: String) async throws -> PathDto {
        try await request(.patch, "/api/searches/\(slug)/paths/\(pathId.uuidString.lowercased())",
                          body: UpdatePathRequest(points: points, finalize: nil),
                          sessionToken: sessionToken)
    }

    func finalizePath(slug: String,
                      pathId: UUID,
                      sessionToken: String) async throws -> PathDto {
        try await request(.patch, "/api/searches/\(slug)/paths/\(pathId.uuidString.lowercased())",
                          body: UpdatePathRequest(points: nil, finalize: true),
                          sessionToken: sessionToken)
    }

    // MARK: - Manage (owner-authed)

    func updateSearch(slug: String,
                      title: String?,
                      expiresAt: Date?,
                      ownerToken: String) async throws -> UpdateSearchResponse {
        try await request(.patch, "/api/searches/\(slug)",
                          body: UpdateSearchRequest(title: title, expiresAt: expiresAt),
                          ownerToken: ownerToken)
    }

    func deleteSearch(slug: String, ownerToken: String) async throws {
        try await requestVoid(.delete, "/api/searches/\(slug)", ownerToken: ownerToken)
    }

    func clearPaths(slug: String, ownerToken: String) async throws -> ClearPathsResponse {
        try await request(.delete, "/api/searches/\(slug)/paths", ownerToken: ownerToken)
    }

    // MARK: - Plumbing

    private enum HTTPMethod: String { case get = "GET", post = "POST", patch = "PATCH", delete = "DELETE" }

    private func makeRequest(_ method: HTTPMethod,
                             _ path: String,
                             body: (any Encodable)? = nil,
                             sessionToken: String? = nil,
                             ownerToken: String? = nil) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(""), resolvingAgainstBaseURL: false)!
        components.path = path
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = sessionToken { req.addValue(t, forHTTPHeaderField: "X-Session-Token") }
        if let t = ownerToken { req.addValue(t, forHTTPHeaderField: "X-Owner-Token") }
        if let body = body {
            req.httpBody = try Self.encoder.encode(AnyEncodable(body))
        }
        return req
    }

    private func request<T: Decodable>(_ method: HTTPMethod,
                                       _ path: String,
                                       body: (any Encodable)? = nil,
                                       sessionToken: String? = nil,
                                       ownerToken: String? = nil) async throws -> T {
        let req = try makeRequest(method, path,
                                  body: body,
                                  sessionToken: sessionToken,
                                  ownerToken: ownerToken)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw ApiError.network(error)
        }
        guard let http = response as? HTTPURLResponse else { throw ApiError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw ApiError.status(http.statusCode, data)
        }
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw ApiError.decoding(error)
        }
    }

    private func requestVoid(_ method: HTTPMethod,
                             _ path: String,
                             body: (any Encodable)? = nil,
                             sessionToken: String? = nil,
                             ownerToken: String? = nil) async throws {
        let req = try makeRequest(method, path,
                                  body: body,
                                  sessionToken: sessionToken,
                                  ownerToken: ownerToken)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw ApiError.network(error)
        }
        guard let http = response as? HTTPURLResponse else { throw ApiError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw ApiError.status(http.statusCode, data)
        }
    }

    // MARK: - JSON encoders / decoders

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(isoFormatter.string(from: date))
        }
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = isoFormatter.date(from: str) { return date }
            if let date = isoFormatterPlain.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container,
                debugDescription: "Unparseable date: \(str)")
        }
        return d
    }()

    // .NET writes 7-digit fractional seconds with "+00:00" offset. Both forms
    // are accepted by ISO8601DateFormatter when .withFractionalSeconds is set.
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

// Type-erased Encodable so we can store heterogeneous bodies in a single
// `body: (any Encodable)?` parameter. JSONEncoder still walks through to
// the underlying type's encoding.
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init<T: Encodable>(_ wrapped: T) { self._encode = wrapped.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
