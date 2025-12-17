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
import SalesforceNavigation

/// Navigation service implementation for handling Salesforce record navigation
class SalesforceNavigationService: SalesforceNavigation.Navigation {

    /// Callback to handle navigation events
    var onNavigate: ((String, String?) -> Void)?

    init(onNavigate: ((String, String?) -> Void)? = nil) {
        self.onNavigate = onNavigate
    }

    /// Navigate to a destination without replacing current context
    /// - Parameter destination: The navigation destination
    func go(to destination: any SalesforceNavigation.Destination) {
        // Default implementation - call the replace version with false
        go(to: destination, replace: false)
    }

    /// Navigate to a destination with option to replace current context
    /// - Parameters:
    ///   - destination: The navigation destination
    ///   - replace: Whether to replace current context
    /// - Note: Intercepts Record navigation and sends to React Native
    func go(to destination: any SalesforceNavigation.Destination, replace: Bool) {
        print("Navigation to: \(destination), replace: \(replace)")

        // Check if destination is a Record
        if let record = destination as? SalesforceNavigation.Record {
            print("Navigating to Record - ID: \(record.id), Type: \(record.type ?? "unknown")")

            // Call the navigation callback with record ID and type
            onNavigate?(record.id, record.type)
        }
    }
}