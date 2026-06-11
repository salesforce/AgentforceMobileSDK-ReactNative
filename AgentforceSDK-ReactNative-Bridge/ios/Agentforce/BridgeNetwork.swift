/*
 * Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.
 *
 * Network implementation for Agentforce DataProvider
 * Uses Mobile SDK RestClient for authenticated API calls
 * Only available when SalesforceSDKCore is present (Employee Agent builds)
 */

import Foundation
import SalesforceNetwork

#if canImport(SalesforceSDKCore)
import SalesforceSDKCore

/**
 * Network implementation that bridges SalesforceNetwork.Network interface
 * to Mobile SDK RestClient for authenticated Salesforce API calls.
 */
struct BridgeNetwork: SalesforceNetwork.Network {

    private let restClient: RestClient

    init(restClient: RestClient = RestClient.shared) {
        self.restClient = restClient
    }

    /// Cap how much of an error body we log so a large HTML/JSON error page
    /// doesn't flood the system log or the JS log channel.
    private static let maxErrorBody = 2048

    func data(for request: SalesforceNetwork.NetworkRequest) async throws -> (Data, URLResponse) {
        let restRequest = try createRestRequest(from: request)
        let method = request.baseRequest.httpMethod ?? "GET"
        let path = request.baseRequest.url?.absoluteString ?? "<no url>"

        return try await withCheckedThrowingContinuation { continuation in
            restClient.send(request: restRequest) { result in
                switch result {
                case let .success(response):
                    let statusCode = (response.urlResponse as? HTTPURLResponse)?.statusCode ?? -1
                    let data = try? response.asData()
                    if statusCode < 200 || statusCode >= 300 {
                        // Non-2xx: log status + a bounded slice of the body. This is what turns
                        // an opaque "Something went wrong" into an actionable cause
                        // (403 = agent not assigned, 404 = wrong agentId, 401 = token/org mismatch).
                        let body = data.flatMap { String(data: $0, encoding: .utf8) }?
                            .prefix(BridgeNetwork.maxErrorBody).description ?? "<no body>"
                        BridgeDiagnostics.error(
                            "BridgeNetwork",
                            "Request NON-2XX status=\(statusCode) \(method) \(path) | body: \(body)"
                        )
                    } else {
                        BridgeDiagnostics.debug(
                            "BridgeNetwork",
                            "Request OK status=\(statusCode) \(method) \(path)"
                        )
                    }
                    if let data = data {
                        continuation.resume(returning: (data, response.urlResponse))
                    } else {
                        BridgeDiagnostics.error("BridgeNetwork", "Request had no data \(method) \(path)")
                        continuation.resume(throwing: NetworkError.noData)
                    }
                case let .failure(error):
                    // Every Agentforce API call flows through here; a swallowed transport
                    // error is what the SDK renders as "Something went wrong".
                    BridgeDiagnostics.error(
                        "BridgeNetwork",
                        "Request FAILED (transport error) \(method) \(path) | error: \(error)"
                    )
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func createRestRequest(from request: NetworkRequest) throws -> RestRequest {
        let method = request.baseRequest.restRequestMethod

        guard let url = request.baseRequest.url else {
            throw NetworkError.invalidURL
        }

        // Determine path based on URL scheme
        // placeholder:// URLs are from DataProvider - extract path so RestClient prepends instance URL
        // Other URLs (https://) should be used as-is (full URL for agent session API, etc.)
        let path: String
        var queryParams: [String: String] = [:]

        if url.scheme == "placeholder" {
            path = url.path
            // Extract query parameters from the URL
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems {
                for item in queryItems {
                    if let value = item.value {
                        queryParams[item.name] = value
                    }
                }
            }
        } else {
            path = url.absoluteString
        }

        let restRequest = RestRequest(method: method, path: path, queryParams: queryParams)

        restRequest.requiresAuthentication = request.requiresAuthentication ?? true

        if let body = request.baseRequest.httpBody {
            let contentType = request.baseRequest.value(forHTTPHeaderField: "Content-Type")
                ?? "application/json; charset=utf-8"
            restRequest.setCustomRequestBodyData(body, contentType: contentType)
        }

        // Set endpoint for paths starting with "/" so RestClient prepends instance URL
        // For full URLs (https://), don't set endpoint
        if path.starts(with: "/") {
            restRequest.endpoint = kSFDefaultRestEndpoint
        } else {
            restRequest.endpoint = ""
        }

        // Copy headers
        if let headerFields = request.baseRequest.allHTTPHeaderFields {
            for (key, value) in headerFields {
                restRequest.setHeaderValue(value, forHeaderName: key)
            }
        }

        return restRequest
    }
}

// MARK: - Extensions

private extension URLRequest {
    var restRequestMethod: RestRequest.Method {
        switch httpMethod {
        case "DELETE": return .DELETE
        case "GET": return .GET
        case "POST": return .POST
        case "PUT": return .PUT
        case "PATCH": return .PATCH
        case "HEAD": return .HEAD
        default: return .GET
        }
    }
}

enum NetworkError: Error {
    case noData
    case invalidURL
}

#endif // canImport(SalesforceSDKCore)
