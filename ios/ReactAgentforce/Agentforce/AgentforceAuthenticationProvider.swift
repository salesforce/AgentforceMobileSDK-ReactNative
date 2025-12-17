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
import AgentforceService
import SalesforceSDKCore

/// Provides authentication credentials for Agentforce SDK using Salesforce authentication
class SalesforceCredentialProvider: AgentforceAuthCredentialProviding {

    /// Returns OAuth credentials from the currently authenticated Salesforce user
    /// - Returns: AgentforceAuthCredentials containing access token, org ID, and user ID
    /// - Note: Throws a fatal error if no authenticated user is found
    func getAuthCredentials() -> AgentforceService.AgentforceAuthCredentials {
        // Get current user from SalesforceSDK
        if let currentUser = UserAccountManager.shared.currentUserAccount,
           let accessToken = currentUser.credentials.accessToken,
           let orgId = currentUser.credentials.organizationId,
           let userId = currentUser.credentials.userId {
            return .OAuth(authToken: accessToken, orgId: orgId, userId: userId)
        }

        // Fallback - this should not happen in a properly authenticated app
        fatalError("No authenticated user found. Please ensure the user is logged in to Salesforce.")
    }
}