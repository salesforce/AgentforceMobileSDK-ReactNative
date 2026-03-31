/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
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

    func data(for request: SalesforceNetwork.NetworkRequest) async throws -> (Data, URLResponse) {
        let restRequest = createRestRequest(from: request)

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

    private func createRestRequest(from request: NetworkRequest) -> RestRequest {
        let method = request.baseRequest.restRequestMethod
        let url = request.baseRequest.url!

        // Determine path based on URL scheme
        // file:// URLs are from DataProvider - extract path so RestClient prepends instance URL
        // Other URLs (https://) should be used as-is (full URL for agent session API, etc.)
        let path: String
        if url.scheme == "file" {
            path = url.path
        } else {
            path = url.absoluteString
        }

        let restRequest = RestRequest(method: method, path: path, queryParams: [:])

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
}

#endif // canImport(SalesforceSDKCore)
