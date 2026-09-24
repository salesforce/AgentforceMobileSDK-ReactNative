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

    // Holds NO RestClient. The current user's RestClient is resolved per request so a
    // logout/login or user switch is reflected immediately, instead of pinning the account
    // that was current when the AgentforceClient (and this BridgeNetwork) was built. A
    // captured client survives AgentforceClient reuse and goes stale after a logout +
    // re-login (revoked refresh token), driving the Mobile SDK to re-launch its login flow.
    private let restClientProvider: () -> RestClient?

    init(restClientProvider: @escaping () -> RestClient? = {
        // RestClient.shared resolves to the *current* user at call time, but its
        // implementation returns nil when there is no current user — gate on
        // currentUserAccount before touching it to avoid an unexpected-nil crash.
        UserAccountManager.shared.currentUserAccount != nil ? RestClient.shared : nil
    }) {
        self.restClientProvider = restClientProvider
    }

    func data(for request: SalesforceNetwork.NetworkRequest) async throws -> (Data, URLResponse) {
        guard let restClient = restClientProvider() else {
            // Logged out / no current user: fail fast rather than sending on a stale
            // client, which would drive the Mobile SDK to launch its own login flow.
            throw NetworkError.notAuthenticated
        }

        let restRequest = try createRestRequest(from: request)

        return try await withCheckedThrowingContinuation { continuation in
            restClient.send(request: restRequest) { result in
                switch result {
                case let .success(response):
                    if let data = try? response.asData() {
                        continuation.resume(returning: (data, response.urlResponse))
                    } else {
                        continuation.resume(throwing: NetworkError.noData)
                    }
                case let .failure(error):
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
    /// No current Mobile SDK user (logged out). Surfaced instead of sending on a stale
    /// RestClient, so the host controls re-authentication rather than the Mobile SDK
    /// launching its own login flow mid-session.
    case notAuthenticated
}

#endif // canImport(SalesforceSDKCore)
