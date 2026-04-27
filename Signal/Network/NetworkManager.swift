// NetworkManager.swift
// Signal
//
// Generic async/await networking layer.
// Even though Signal uses mocked data today, this provides the real
// network plumbing so switching to a live API is a one-line change in Services.

import Foundation

// MARK: - Network Errors

/// Typed errors thrown by NetworkManager.
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
final class NetworkManager {
    
    // Shared singleton — avoids spinning up multiple URLSession stacks.
    static let shared = NetworkManager()
    private let session: URLSession
    private init(session: URLSession = .shared) {
        self.session = session
    }
    
    func request<T: Decodable>(url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.unknown(URLError(.badServerResponse))
        }
        guard (200...299).contains(http.statusCode) else {
            throw NetworkError.badStatusCode(http.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
}
