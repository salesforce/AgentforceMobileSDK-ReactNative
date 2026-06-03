/*
 * Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.
 *
 * DataProvider implementation for Agentforce SDK
 * Uses Network interface to fetch record data from Salesforce UI APIs
 * Only available when SalesforceSDKCore is present (Employee Agent builds)
 */

import Foundation
import AgentforceSDK
import SalesforceNetwork

#if canImport(SalesforceSDKCore)
import SalesforceSDKCore

/**
 * DataProvider implementation that uses Network to fetch record data.
 * Conforms to AgentforceDataProviding protocol required by AgentforceConfiguration.
 */
struct BridgeDataProvider: AgentforceDataProviding {

    private static let apiVersion = "v62.0"

    private let network: SalesforceNetwork.Network
    private let restClient: RestClient

    init(network: SalesforceNetwork.Network, restClient: RestClient = RestClient.shared) {
        self.network = network
        self.restClient = restClient
    }

    func record(
        for objectType: String,
        recordId: String,
        fields: [String],
        cachePolicy: AgentforceCachePolicy,
        transactionId: String?
    ) async throws -> AgentforceRecordRepresentation {
        // When fields is empty, omit the parameter and let the UI API return its defaults.
        // This avoids hardcoding "Name" which doesn't exist on all objects (e.g., Task uses Subject).
        let fieldsParam: String
        if !fields.isEmpty {
            var fieldsToRequest = fields
            if !fieldsToRequest.contains("Id") {
                fieldsToRequest.insert("Id", at: 0)
            }
            // UI API requires qualified field names (ObjectType.FieldName)
            let qualifiedFields = fieldsToRequest.map { field in
                field.contains(".") ? field : "\(objectType).\(field)"
            }
            fieldsParam = "?fields=" + qualifiedFields.joined(separator: ",")
        } else {
            fieldsParam = ""
        }

        let path = "/services/data/\(Self.apiVersion)/ui-api/records/\(recordId)\(fieldsParam)"

        let request = createNetworkRequest(path: path)
        let (data, _) = try await network.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return try parseRecordRepresentation(from: json)
    }

    func record(
        forLayoutType layoutType: String,
        recordId: String,
        modes: [AgentforceAccessMode],
        cachePolicy: AgentforceCachePolicy,
        transactionId: String?
    ) async throws -> AgentforceRecordRepresentation {
        // Note: `modes` is not used. The records endpoint (used here instead of record-ui)
        // does not support access modes.

        // Uses the records endpoint with layoutTypes when available.
        // When layoutType is empty, omit it and let the UI API return defaults
        // rather than hardcoding field names that may not exist on all objects.
        let path: String
        if !layoutType.isEmpty {
            let encodedLayoutType = layoutType.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? layoutType
            path = "/services/data/\(Self.apiVersion)/ui-api/records/\(recordId)?layoutTypes=\(encodedLayoutType)"
        } else {
            path = "/services/data/\(Self.apiVersion)/ui-api/records/\(recordId)"
        }

        let request = createNetworkRequest(path: path)
        let (data, _) = try await network.data(for: request)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        // Both records and record-ui endpoints return the record directly in the response
        return try parseRecordRepresentation(from: json)
    }

    func records(
        forObjectType objectType: String,
        recordIds: [String],
        fields: [String],
        cachePolicy: AgentforceCachePolicy,
        transactionId: String?
    ) async throws -> [AgentforceUIAPIRecord] {
        let recordIdsParam = recordIds.joined(separator: ",")

        // UI API requires qualified field names (ObjectType.FieldName) when using fields parameter
        let fieldsParam: String
        if !fields.isEmpty {
            let qualifiedFields = fields.map { field in
                field.contains(".") ? field : "\(objectType).\(field)"
            }
            fieldsParam = "?fields=" + qualifiedFields.joined(separator: ",")
        } else {
            fieldsParam = ""
        }

        let path = "/services/data/\(Self.apiVersion)/ui-api/records/batch/\(recordIdsParam)\(fieldsParam)"

        let request = createNetworkRequest(path: path)
        let (data, _) = try await network.data(for: request)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        if let results = json["results"] as? [[String: Any]] {
            return try results.compactMap { resultItem in
                if let statusCode = resultItem["statusCode"] as? Int, statusCode == 200,
                   let recordData = resultItem["result"] as? [String: Any] {
                    return try parseUIAPIRecord(from: recordData)
                }
                return nil
            }
        }
        return []
    }

    func records(
        forLayoutType layoutType: String,
        recordIds: [String],
        modes: [AgentforceAccessMode]?,
        cachePolicy: AgentforceCachePolicy,
        transactionId: String?
    ) async throws -> [AgentforceUIAPIRecord] {
        // Note: `modes` is not used. records/batch does not support access modes.

        // UI API does not have a record-ui/batch endpoint, only records/batch
        let recordIdsParam = recordIds.joined(separator: ",")

        // If layoutType is provided and not empty, use it; otherwise let the API return defaults
        let queryParam: String
        if !layoutType.isEmpty {
            let encodedLayoutType = layoutType.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? layoutType
            queryParam = "?layoutTypes=\(encodedLayoutType)"
        } else {
            queryParam = ""
        }

        let path = "/services/data/\(Self.apiVersion)/ui-api/records/batch/\(recordIdsParam)\(queryParam)"

        let request = createNetworkRequest(path: path)
        let (data, _) = try await network.data(for: request)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        if let results = json["results"] as? [[String: Any]] {
            return try results.compactMap { resultItem in
                // records/batch returns the record directly in each result, not nested under "record"
                if let statusCode = resultItem["statusCode"] as? Int, statusCode == 200,
                   let recordData = resultItem["result"] as? [String: Any] {
                    return try parseUIAPIRecord(from: recordData)
                }
                return nil
            }
        }
        return []
    }

    func objectInfo(
        for objectType: String,
        cachePolicy: AgentforceCachePolicy,
        transactionId: String?
    ) async throws -> AgentforceObjectRepresentation {
        let path = "/services/data/\(Self.apiVersion)/ui-api/object-info/\(objectType)"
        let request = createNetworkRequest(path: path)
        let (data, _) = try await network.data(for: request)
        let objectInfoResponse = try JSONDecoder().decode(UIAPIObjectInfoRepresentation.self, from: data)
        return objectInfoResponse.toObjectRepresentation()
    }

    func objectInfos(
        forObjectTypes objectTypes: [String],
        cachePolicy: AgentforceCachePolicy,
        transactionId: String?
    ) async throws -> [AgentforceUIAPIObjectInfo] {
        let objectTypesParam = objectTypes.joined(separator: ",")
        let path = "/services/data/\(Self.apiVersion)/ui-api/object-info/batch/\(objectTypesParam)"
        let request = createNetworkRequest(path: path)
        let (data, _) = try await network.data(for: request)
        let batchResponse = try JSONDecoder().decode(UIAPIObjectInfoBatchResponse.self, from: data)
        return batchResponse.results.compactMap { $0.statusCode == 200 ? $0.result : nil }
    }

    func query(
        for data: AgentforceQueryData,
        cachePolicy: AgentforceCachePolicy,
        transactionId: String?
    ) async throws -> [String: Any] {
        throw DataProviderError.notImplemented
    }

    // MARK: - Parsing Helpers

    private func parseRecordRepresentation(from json: [String: Any]) throws -> AgentforceRecordRepresentation {
        guard let recordId = json["id"] as? String,
              let objectType = json["apiName"] as? String else {
            throw DataProviderError.invalidResponse
        }

        // Extract fields from UI API format.
        // fields holds raw values (IDs, API values) so SDK lookups/navigation work correctly.
        var parsedFields: [String: Any] = [:]
        var displayFields: [AgentforceListDisplayColumn] = []

        if let fieldsData = json["fields"] as? [String: Any] {
            for key in fieldsData.keys.sorted() {
                guard let fieldValue = fieldsData[key] as? [String: Any],
                      let actualValue = fieldValue["value"] else { continue }
                parsedFields[key] = actualValue
                if key != "Id", !(actualValue is NSNull) {
                    displayFields.append(AgentforceListDisplayColumn(fieldApiName: key, label: key))
                }
            }
        }

        return AgentforceRecordRepresentation(
            recordId: recordId,
            objectType: objectType,
            iconUrl: nil,
            iconColor: nil,
            displayFields: displayFields,
            fields: parsedFields,
            fieldmap: nil
        )
    }

    private func parseUIAPIRecord(from json: [String: Any]) throws -> AgentforceUIAPIRecord {
        // AgentforceUIAPIRecord is Decodable, so convert dict back to Data and decode
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(AgentforceUIAPIRecord.self, from: data)
    }

    private func createNetworkRequest(path: String) -> SalesforceNetwork.NetworkRequest {
        // Use a placeholder URL - BridgeNetwork will use the path directly
        // We use "placeholder://api" as a valid URL that signals path-only usage
        guard let url = URL(string: "placeholder://api" + path) else {
            fatalError("Invalid path for network request: \(path)")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        return NetworkRequest(baseRequest: urlRequest)
    }
}

// MARK: - Supporting Types

/// Intermediate representation for UI API object info that can be decoded from JSON
private struct UIAPIObjectInfoRepresentation: Codable {
    let apiName: String
    let label: String
    let labelPlural: String
    let fields: [String: Field]
    let nameFields: [String]
    let themeInfo: ThemeInfo

    struct Field: Codable {
        let apiName: String
        let dataType: String
        let label: String
        let reference: Bool
        let referenceToInfos: [ReferenceInfo]

        struct ReferenceInfo: Codable {
            let apiName: String
            let nameFields: [String]
        }
    }

    struct ThemeInfo: Codable {
        let iconUrl: String?
        let color: String?
    }

    func toObjectRepresentation() -> AgentforceObjectRepresentation {
        var convertedFields = [String: AgentforceObjectRepresentation.Field]()
        for (key, value) in fields {
            let convertedRefs = value.referenceToInfos.map {
                AgentforceObjectRepresentation.Field.ReferenceInfo(
                    apiName: $0.apiName,
                    nameFields: $0.nameFields
                )
            }
            convertedFields[key] = AgentforceObjectRepresentation.Field(
                apiName: value.apiName,
                dataType: value.dataType,
                label: value.label,
                reference: value.reference,
                referenceToInfos: convertedRefs
            )
        }

        return AgentforceObjectRepresentation(
            objectType: apiName,
            label: label,
            labelPlural: labelPlural,
            fields: convertedFields,
            nameFields: nameFields,
            theme: .init(
                iconUrl: themeInfo.iconUrl,
                iconColor: themeInfo.color ?? ""
            )
        )
    }
}

private struct UIAPIObjectInfoBatchResponse: Decodable {
    let results: [BatchResult]

    struct BatchResult: Decodable {
        let result: AgentforceUIAPIObjectInfo
        let statusCode: Int?
    }
}

enum DataProviderError: Error {
    case invalidURL
    case invalidResponse
    case notImplemented
}

#endif // canImport(SalesforceSDKCore)
