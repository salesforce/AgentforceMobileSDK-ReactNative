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
import AgentforceSDK
import SalesforceNetwork
import SalesforceCache

/// Errors that can occur when using AgentforceDataProvider implementations.
public enum AgentforceDataProviderError: Error {
    case APINotImplemented
    case BadURL
    case NoNetworkAPI
    case DecodeFailure
    case unknown
}

/// Helper struct for building GraphQL WHERE clause filters
struct WhereFieldFilter: CustomStringConvertible {
    let field: String
    let op: String
    let value: String

    init(field: String, op: String = "eq", value: String) {
        self.field = field
        self.op = op
        self.value = value
    }

    var description: String {
        // Currently, UEM accepts "Where" values as: ["Name": "John Smith"]
        // without an operator designated -- add an operator to this case
        if value.first != "{" {
            return "\(field): {\(op): \\\"\(value)\\\"}"
        }
        return "\(field): \(value)"
    }
}

/// Response structures for parsing Salesforce API responses
struct UIAPIResponse: Decodable {
    let records: [String: AgentforceUIAPIRecord]
    let objectInfos: [String: AgentforceUIAPIObjectInfo]
}

struct UIAPIObjectRepresentation: Codable {
    let apiName: String
    let label: String
    let labelPlural: String
    let fields: [String: Field]?
    let nameFields: [String]?
    let themeInfo: UIAPIThemeInfo

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

    func toObjectRepresentation() -> AgentforceObjectRepresentation {
        var orFields = [String: AgentforceObjectRepresentation.Field]()
        if let fields = fields {
            for (key, value) in fields {
                orFields[key] = AgentforceObjectRepresentation.Field(
                    apiName: value.apiName,
                    dataType: value.dataType,
                    label: value.label,
                    reference: value.reference,
                    referenceToInfos: value.referenceToInfos.map {
                        AgentforceObjectRepresentation.Field.ReferenceInfo(
                            apiName: $0.apiName,
                            nameFields: $0.nameFields
                        )
                    }
                )
            }
        }
        return AgentforceObjectRepresentation(
            objectType: apiName,
            label: label,
            labelPlural: labelPlural,
            fields: orFields,
            nameFields: nameFields,
            theme: AgentforceThemeRepresentation(
                iconUrl: themeInfo.iconUrl,
                iconColor: themeInfo.color
            )
        )
    }
}

struct UIAPIThemeInfo: Codable {
    let color: String
    let iconUrl: String
}

struct UIAPIObjectBatchResponse: Decodable {
    let result: AgentforceUIAPIObjectInfo
    let statusCode: Int?
}

struct UIAPIObjectInfosResponse: Decodable {
    let results: [UIAPIObjectBatchResponse]
}

struct GraphQLResponse {
    enum RootKey: String, CodingKey {
        case data
    }

    enum UIAPIKey: String, CodingKey {
        case uiapi
    }

    enum QueryKey: String, CodingKey {
        case query
    }

    let response: [String: Any]
}

extension GraphQLResponse: Decodable {
    init(from decoder: Decoder) throws {
        // For GraphQL responses, we need to manually parse the JSON
        // since [String: Any] doesn't conform to Decodable
        let container = try decoder.container(keyedBy: RootKey.self)
        let dataContainer = try container.nestedContainer(keyedBy: UIAPIKey.self, forKey: .data)
        let uiapiContainer = try dataContainer.nestedContainer(keyedBy: QueryKey.self, forKey: .uiapi)

        // Get the raw data and parse it manually
        if let data = try? uiapiContainer.decode(AnyCodable.self, forKey: .query) {
            self.response = data.value as? [String: Any] ?? [:]
        } else {
            self.response = [:]
        }
    }
}

/// Helper struct to decode Any values from JSON
private struct AnyCodable: Codable {
    let value: Any

    init(value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else if let array = value as? [Any] {
            let encodableArray = array.map { AnyCodable(value: $0) }
            try container.encode(encodableArray)
        } else if let dict = value as? [String: Any] {
            let encodableDict = dict.mapValues { AnyCodable(value: $0) }
            try container.encode(encodableDict)
        } else {
            try container.encodeNil()
        }
    }
}

/// Data provider that implements AgentforceDataProviding without MobileCustomizationFramework dependencies
public class AgentforceDataProvider {
    private let cache: Cache
    private let network: Network

    public init(cache: Cache, network: Network) {
        self.cache = cache
        self.network = network
    }
}

// MARK: - AgentforceDataProviding Implementation
extension AgentforceDataProvider: AgentforceDataProviding {
    enum Constants {
        static let BASE_URL = "/services/data/"
        static let API_VERSION = "v57.0"
        static let OBJECT_INFO = "/ui-api/object-info/"
        static let RECORDS = "/ui-api/records/"
        static let RECORD_UI = "/ui-api/record-ui/"
        static let GRAPHQL = "/graphql"
        static let OBJECT_INFOS = "/ui-api/object-info/batch/"
    }

    /// Retrieves a single record with specified fields
    public func record(
        for objectType: String,
        recordId: String,
        fields: [String],
        cachePolicy: AgentforceCachePolicy,
        transactionId: String?
    ) async throws -> AgentforceRecordRepresentation {
        let fieldQuery = fields.map { "\(objectType).\($0)" }.joined(separator: ",")
        guard let url = URL(string: "\(Constants.BASE_URL)\(Constants.API_VERSION)\(Constants.RECORDS)\(recordId)?fields=\(fieldQuery)"),
              let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw AgentforceDataProviderError.BadURL
        }

        let urlRequest = URLRequest(url: urlComponents.url!)
        let netRequest = NetworkRequest(baseRequest: urlRequest)

        let data = try await getNetworkData(netRequest)
        do {
            let rawResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            if let recordId = rawResponse?["id"] as? String,
               let objectType = rawResponse?["apiName"] as? String,
               let fields = rawResponse?["fields"] as? [String: Any] {
                return AgentforceRecordRepresentation(
                    recordId: recordId,
                    objectType: objectType,
                    displayFields: [], // Empty for now, can be enhanced later
                    fields: fields,
                    fieldmap: nil
                )
            } else {
                throw AgentforceDataProviderError.DecodeFailure
            }
        }
    }

    /// Retrieves multiple records using layout-based field selection
    public func records(
        forLayoutType layoutType: String,
        recordIds: [String],
        modes: [AgentforceAccessMode]?,
        cachePolicy: AgentforceCachePolicy,
        transactionId: String?
    ) async throws -> [AgentforceUIAPIRecord] {
        guard let url = URL(string: "\(Constants.BASE_URL)\(Constants.API_VERSION)\(Constants.RECORD_UI)\(recordIds.joined(separator: ","))?layoutTypes=\(layoutType)"),
              let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw AgentforceDataProviderError.BadURL
        }

        let urlRequest = URLRequest(url: urlComponents.url!)
        let netRequest = NetworkRequest(baseRequest: urlRequest)

        let data = try await getNetworkData(netRequest)
        let response = try JSONDecoder().decode(UIAPIResponse.self, from: data)

        // Cache objectInfos
        for (key, value) in response.objectInfos {
            if let data = try? JSONEncoder().encode(value) {
                _ = try await cache.save(data, key: "ObjectInfo-\(key)")
            }
        }

        return response.records.map { _, value in
            value
        }
    }

    /// Retrieves metadata information for a Salesforce object type
    public func objectInfo(
        for objectType: String,
        cachePolicy: AgentforceCachePolicy,
        transactionId: String?
    ) async throws -> AgentforceObjectRepresentation {

        // Check cache first based on policy
        if cachePolicy != .networkOnly {
            if let cachedEntry = try await cache.load("ObjectInfo-\(objectType)"),
               let objectInfo = try? JSONDecoder().decode(AgentforceUIAPIObjectInfo.self, from: cachedEntry) {

                return AgentforceObjectRepresentation(
                    objectType: objectType,
                    label: objectInfo.label,
                    labelPlural: objectInfo.labelPlural,
                    theme: AgentforceThemeRepresentation(
                        iconUrl: objectInfo.themeInfo?.iconUrl,
                        iconColor: objectInfo.themeInfo?.color ?? "#000000"
                    )
                )
            }
        }

        guard let url = URL(string: "\(Constants.BASE_URL)\(Constants.API_VERSION)\(Constants.OBJECT_INFO)\(objectType)"),
              let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw AgentforceDataProviderError.BadURL
        }

        let urlRequest = URLRequest(url: urlComponents.url!)
        let netRequest = NetworkRequest(baseRequest: urlRequest)

        let data = try await getNetworkData(netRequest)
        var objectInfoResponse: UIAPIObjectRepresentation
        do {
            objectInfoResponse = try JSONDecoder().decode(UIAPIObjectRepresentation.self, from: data)

            // Cache the response
            if let encodedData = try? JSONEncoder().encode(objectInfoResponse) {
                _ = try await cache.save(encodedData, key: "ObjectInfo-\(objectType)")
            }

            return objectInfoResponse.toObjectRepresentation()
        }
    }

    /// Retrieves metadata information for multiple Salesforce object types
    public func objectInfos(
        forObjectTypes objectTypes: [String],
        cachePolicy: AgentforceCachePolicy,
        transactionId: String?
    ) async throws -> [AgentforceUIAPIObjectInfo] {

        var objectInfos: [AgentforceUIAPIObjectInfo] = []
        var objectInfosToQuery = objectTypes

        // Check cache for existing object infos based on policy
        if cachePolicy != .networkOnly {
            for objectType in objectTypes {
                if let cachedEntry = try await cache.load("ObjectInfo-\(objectType)"),
                   let objectInfo = try? JSONDecoder().decode(AgentforceUIAPIObjectInfo.self, from: cachedEntry) {
                    objectInfos.append(objectInfo)
                    objectInfosToQuery.removeAll(where: { $0.caseInsensitiveCompare(objectType) == .orderedSame })
                }
            }
        }

        // Early exit if we have everything we need from cache
        if objectInfosToQuery.isEmpty {
            return objectInfos
        }

        guard let url = URL(string: "\(Constants.BASE_URL)\(Constants.API_VERSION)\(Constants.OBJECT_INFOS)\(objectInfosToQuery.joined(separator: ","))"),
              let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw AgentforceDataProviderError.BadURL
        }

        let urlRequest = URLRequest(url: urlComponents.url!)
        let netRequest = NetworkRequest(baseRequest: urlRequest)

        let data = try await getNetworkData(netRequest)
        do {
            let response = try JSONDecoder().decode(UIAPIObjectInfosResponse.self, from: data)
            let returnedObjectInfos = response.results.compactMap { $0.statusCode == 200 ? $0.result : nil }
            objectInfos.append(contentsOf: returnedObjectInfos)

            // Cache the returned object infos
            for objectInfo in returnedObjectInfos {
                if let encodedData = try? JSONEncoder().encode(objectInfo) {
                    _ = try await cache.save(encodedData, key: "ObjectInfo-\(objectInfo.apiName)")
                }
            }
        }

        return objectInfos
    }

    /// Executes a query and returns matching records
    public func query(
        for data: AgentforceQueryData,
        cachePolicy: AgentforceCachePolicy,
        transactionId: String?
    ) async throws -> [String: Any] {
        guard let url = URL(string: "\(Constants.BASE_URL)\(Constants.API_VERSION)\(Constants.GRAPHQL)"),
              let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw AgentforceDataProviderError.BadURL
        }

        let whereString = whereClauseFor(whereMap: data.whereMap)
        var orderByString = ""
        if let orderBy = data.orderBy {
            orderByString = orderByJSONFor(orderByProperty: orderBy)
        }

        let queryString = buildQuery(
            objectType: data.objectType,
            size: data.size,
            fields: data.fields,
            orderByClause: orderByString,
            whereClause: whereString
        )

        var urlRequest = URLRequest(url: urlComponents.url!)
        let jsonData = Data(queryString.utf8)
        urlRequest.httpBody = jsonData
        urlRequest.httpMethod = "POST"
        var netRequest = NetworkRequest(baseRequest: urlRequest)
        netRequest.baseRequest.httpBody = jsonData
        netRequest.baseRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let responseData = try await getNetworkData(netRequest)
        let graphQLResponse = try JSONDecoder().decode(GraphQLResponse.self, from: responseData)
        let topLevel: [String: Any] = graphQLResponse.response[data.objectType] as? [String: Any] ?? [:]

        return topLevel
    }
}

// MARK: - Private Helper Methods
private extension AgentforceDataProvider {
    func getNetworkData(_ request: NetworkRequest) async throws -> Data {
        let (data, _) = try await network.data(for: request)
        return data
    }

    func buildQuery(
        objectType: String,
        size: Int,
        fields: [String: String],
        orderByClause: String,
        whereClause: String?
    ) -> String {
        var nodes = "Id "
        for (field, fieldType) in fields {
            nodes += queryNodeFor(field: field, fieldType: fieldType)
        }

        let graphQL = """
        {"query":
        "query { uiapi { query { \
        \(objectType)(first: 200, \
        \(whereClause ?? ""), \
        \(orderByClause)) { \
        edges { node { \(nodes) }}}}}}"
        }
        """
        return graphQL
    }

    func whereClauseFor(whereMap: [String: Any]?, initialWhereConditions: String? = "IsDeleted: {eq: false}") -> String? {
        var whereClause = "where: {"

        if let initialWhereConditions = initialWhereConditions {
            whereClause.append(initialWhereConditions)
        }

        if let subClause = _whereClauseFor(whereMap: whereMap, isRecursed: false) {
            if initialWhereConditions != nil {
                whereClause.append(", ")
            }

            whereClause.append(subClause)
        }
        whereClause.append("}")
        return whereClause
    }

    func _whereClauseFor(whereMap: [String: Any]?, isRecursed: Bool) -> String? {
        guard let whereMap = whereMap, !whereMap.isEmpty else { return nil }
        var whereClause = ""

        var removeTrailing = false
        for whereStatement in whereMap {
            if ["and", "or"].contains(whereStatement.key), let subMap = whereStatement.value as? [String: Any] {
                if let subClause = _whereClauseFor(whereMap: subMap, isRecursed: true) {
                    whereClause.append("\(whereStatement.key): [\(subClause)], ")
                    removeTrailing = true
                }
            } else {
                let whereFieldFilter = WhereFieldFilter(field: whereStatement.key, value: "\(whereStatement.value)")
                if isRecursed {
                    whereClause.append("{\(whereFieldFilter.description)}, ")
                } else {
                    whereClause.append("\(whereFieldFilter.description), ")
                }
                removeTrailing = true
            }
        }

        // Trim extraneous delimiters
        if removeTrailing {
            whereClause.removeLast(2)
        }
        return whereClause
    }

    func orderByJSONFor(orderByProperty: [[String: String]]) -> String {
        var orderBy = ""
        for entry in orderByProperty {
            for (fieldName, order) in entry {
                orderBy += "\(fieldName): {order: \(order), nulls: LAST} "
            }
        }
        return "orderBy: { \(orderBy) }"
    }

    func queryNodeFor(field: String, fieldType: String) -> String {
        var node = "\(field) "

        if fieldType.hasSuffix("Value") {
            node += " { value, displayValue } "
        }
        return node
    }
}
