/*
 Copyright (c) 2020-present, salesforce.com, inc. All rights reserved.

 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation
import SalesforceNetwork
import SalesforceSDKCore

/// Custom errors for network operations
public enum NetworkErrors: Error {
    case noData
}

/// Extension to map URLRequest HTTP methods to RestRequest methods
private extension URLRequest {
    var restRequestMethod: RestRequest.Method {
        switch httpMethod {
        case "DELETE":
            return RestRequest.Method.DELETE
        case "GET":
            return RestRequest.Method.GET
        case "POST":
            return RestRequest.Method.POST
        case "PUT":
            return RestRequest.Method.PUT
        case "PATCH":
            return RestRequest.Method.PATCH
        case "HEAD":
            return RestRequest.Method.HEAD
        default:
            fatalError("Unknown method")
        }
    }
}

/// Network provider implementation using Salesforce REST APIs
class SalesforceNetworkProvider: SalesforceNetwork.Network {

    /// REST client for making API calls
    var restAPI: RestClient

    /// Initialize with optional custom RestClient
    /// - Parameter restClient: RestClient instance (defaults to shared instance)
    init(restClient: RestClient = RestClient.shared) {
        self.restAPI = restClient
    }

    /// Performs network request and returns data and response
    /// - Parameter request: NetworkRequest to execute
    /// - Returns: Tuple containing response data and URLResponse
    /// - Throws: Network errors including authentication and data issues
    func data(for request: SalesforceNetwork.NetworkRequest) async throws -> (Data, URLResponse) {
        let restRequest = restRequest(request: request)

        return try await withCheckedThrowingContinuation { continuation in
            restAPI.send(request: restRequest) { result in
                switch result {
                case let .success(response):
                    if let data = try? result.get().asData() {
                        continuation.resume(returning: (data, response.urlResponse))
                    } else {
                        continuation.resume(throwing: NetworkErrors.noData)
                    }
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Converts NetworkRequest to Salesforce RestRequest
    /// - Parameter request: NetworkRequest to convert
    /// - Returns: RestRequest configured for Salesforce APIs
    func restRequest(request: NetworkRequest) -> RestRequest {
        let urlString = request.baseRequest.url!.absoluteString
        let restReq = RestRequest(method: request.baseRequest.restRequestMethod, path: urlString, queryParams: [:])
        restReq.requiresAuthentication = request.requiresAuthentication ?? true
        let contentType = request.baseRequest.value(forHTTPHeaderField: "Content-Type") ?? "application/json; charset=utf-8"

        if let body = request.baseRequest.httpBody {
            restReq.setCustomRequestBodyData(body, contentType: contentType)
        }

        if urlString.starts(with: "/") {
            restReq.endpoint = kSFDefaultRestEndpoint
        } else {
            restReq.endpoint = ""
        }

        if let headerFields = request.baseRequest.allHTTPHeaderFields {
            for (key, value) in headerFields {
                restReq.setHeaderValue(value, forHeaderName: key)
            }
        }

        return restReq
    }
}