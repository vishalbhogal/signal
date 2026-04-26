// NetworkManager.swift
// Signal
//
// Generic async/await networking layer.
// Even though Signal uses mocked data today, this provides the real
// network plumbing so switching to a live API is a one-line change in Services.

import Foundation

// MARK: - Network Errors

/// Typed errors thrown by NetworkManager.
/// Typed errors (instead of generic Error) let callers handle each failure case distinctly.
enum NetworkError: LocalizedError {
    case invalidURL
    case badStatusCode(Int)     // e.g. 404, 500
    case decodingFailed(Error)  // JSON didn't match our model
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:              return "The URL was malformed."
        case .badStatusCode(let code): return "Server returned status \(code)."
        case .decodingFailed:          return "Response data didn't match expected format."
        case .unknown(let e):          return e.localizedDescription
        }
    }
}

// MARK: - Network Manager

/// Wraps URLSession with a generic decode-on-success pattern.
/// `async throws` means callers use try await — no completion handlers needed.
final class NetworkManager {

    // Shared singleton — avoids spinning up multiple URLSession stacks.
    static let shared = NetworkManager()

    // URLSession handles the actual HTTP connection pool, caching, and cookies.
    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Generic Request

    /// Fetch any Decodable type from a URL.
    /// `<T: Decodable>` is a generic — this one function works for any model type.
    ///
    /// Usage:
    ///   let profile: ClinicianProfile = try await NetworkManager.shared.request(url: someURL)
    func request<T: Decodable>(url: URL) async throws -> T {

        // `session.data(from:)` is the async/await version of dataTask.
        // `await` suspends this function (not the thread) until the response arrives.
        let (data, response) = try await session.data(from: url)

        // Cast to HTTPURLResponse to read the status code.
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.unknown(URLError(.badServerResponse))
        }

        // HTTP 200–299 = success. Anything else is an error we surface to the caller.
        guard (200...299).contains(http.statusCode) else {
            throw NetworkError.badStatusCode(http.statusCode)
        }

        // JSONDecoder maps JSON keys to Swift properties.
        // If the shapes don't match, decodingFailed is thrown instead of crashing.
        do {
            let decoder = JSONDecoder()
            // .iso8601 tells the decoder how Date values are encoded in the JSON.
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
}
