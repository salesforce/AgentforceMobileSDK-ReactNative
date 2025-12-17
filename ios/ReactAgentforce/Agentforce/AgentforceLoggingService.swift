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
import SalesforceLogging
import SalesforceSDKCore

/// Logging service implementation that bridges Agentforce logging to Salesforce SDK logging
class SalesforceLoggerService: SalesforceLogging.Logger {

    /// Log a message with specified level
    /// - Parameters:
    ///   - logMessage: The message to log
    ///   - level: The logging level
    /// - Note: Maps Agentforce log levels to appropriate Salesforce SDK log levels
    func log(_ logMessage: String, level: SalesforceLogging.LogLevel) {
        // Map to SalesforceSDK logging using the new API
        let sfLogLevel: SalesforceLogger.Level
        switch level {
        case .debug:
            sfLogLevel = .debug
        case .info:
            sfLogLevel = .info
        case .warning:
            sfLogLevel = .error  // Use error level if warning doesn't exist
        case .error:
            sfLogLevel = .error
        @unknown default:
            sfLogLevel = .info
        }

        SalesforceLogger.d(type(of: self), message: logMessage)
    }
}