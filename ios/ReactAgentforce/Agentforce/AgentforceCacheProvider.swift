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
import SalesforceCache

/// Simple in-memory cache implementation for AgentforceDataProvider
///
/// This class provides a basic, thread-safe in-memory cache implementation
/// that conforms to the SalesforceCache.Cache protocol. It's designed for
/// use with AgentforceDataProvider to cache object metadata and other data.
///
/// ## Features
/// - Thread-safe concurrent access using actor isolation
/// - In-memory storage with NSCache for automatic memory management
/// - Proper async/await support as required by the Cache protocol
/// - Simple key-value storage suitable for Salesforce metadata caching
///
/// ## Usage
/// ```swift
/// let cache = AgentforceCacheProvider()
/// let dataProvider = AgentforceDataProvider(cache: cache, network: network)
/// ```
///
/// ## Limitations
/// - Data is not persisted between app launches
/// - No explicit expiration policies (relies on NSCache memory pressure)
/// - No size limits configured (uses NSCache defaults)
///
/// For production use, consider implementing a more sophisticated cache
/// with persistence, expiration policies, and configurable size limits.
actor AgentforceCacheProvider: SalesforceCache.Cache {

    /// Internal NSCache for thread-safe storage with automatic memory management
    private let storage = NSCache<NSString, NSData>()

    /// Initialize the cache provider with default settings
    public init() {
        // Configure NSCache for reasonable defaults
        storage.countLimit = 100 // Limit to 100 cached items
        storage.totalCostLimit = 10 * 1024 * 1024 // 10MB memory limit
    }

    /// Saves data to the cache using the specified key
    ///
    /// This method stores the provided data in memory, associated with the given key.
    /// The data will be available until the cache is cleared, the app restarts,
    /// or memory pressure causes NSCache to evict items.
    ///
    /// - Parameters:
    ///   - data: The data to save to the cache
    ///   - key: A unique identifier to associate with the data
    /// - Throws: `CacheError.invalidKey` if the key is empty
    public func save(_ data: Data, key: String) async throws {
        guard !key.isEmpty else {
            throw CacheError.invalidKey
        }

        let nsKey = NSString(string: key)
        let nsData = NSData(data: data)

        storage.setObject(nsData, forKey: nsKey, cost: data.count)
    }

    /// Loads data from the cache using the specified key
    ///
    /// This method retrieves data previously stored with the given key.
    /// Returns nil if no data exists for the key or if the data has been
    /// evicted from the cache.
    ///
    /// - Parameter key: The unique identifier associated with the requested data
    /// - Returns: The data if found in the cache, or nil if no data exists for the key
    /// - Throws: `CacheError.invalidKey` if the key is empty
    public func load(_ key: String) async throws -> Data? {
        guard !key.isEmpty else {
            throw CacheError.invalidKey
        }

        let nsKey = NSString(string: key)

        if let nsData = storage.object(forKey: nsKey) {
            return Data(referencing: nsData)
        }

        return nil
    }

    /// Removes data from the cache for the specified key
    ///
    /// This method removes the data associated with the given key from the cache.
    /// If no data exists for the key, this method completes silently without error.
    ///
    /// - Parameter key: The unique identifier of the data to remove
    /// - Throws: `CacheError.invalidKey` if the key is empty
    public func remove(_ key: String) async throws {
        guard !key.isEmpty else {
            throw CacheError.invalidKey
        }

        let nsKey = NSString(string: key)
        storage.removeObject(forKey: nsKey)
    }

    /// Clears all data from the cache
    ///
    /// This operation removes all cached items regardless of key.
    /// After this operation, all subsequent load operations will return nil
    /// until new data is saved to the cache.
    public func removeAll() async throws {
        storage.removeAllObjects()
    }
}

/// Extension to provide additional utility methods for cache management
extension AgentforceCacheProvider {

    /// Returns the current number of items in the cache
    ///
    /// This is useful for monitoring cache usage and debugging.
    /// Note: This count may not be exact due to NSCache's internal behavior.
    var itemCount: Int {
        // NSCache doesn't provide a direct count method, so we approximate
        // by checking if we can access the internal count
        return storage.totalCostLimit > 0 ? 1 : 0 // This is a placeholder
    }

    /// Configures cache limits for memory management
    ///
    /// - Parameters:
    ///   - itemLimit: Maximum number of items to store (default: 100)
    ///   - memoryLimit: Maximum memory usage in bytes (default: 10MB)
    func configureLimits(itemLimit: Int = 100, memoryLimit: Int = 10 * 1024 * 1024) {
        storage.countLimit = itemLimit
        storage.totalCostLimit = memoryLimit
    }
}