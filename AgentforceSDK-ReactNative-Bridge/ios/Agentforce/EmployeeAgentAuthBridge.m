/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 *
 * React Native bridge for Employee Agent auth via Salesforce Mobile SDK.
 * When Mobile SDK is present (pod 'ReactNativeAgentforce/WithMobileSDK'), isAuthSupported is YES
 * and methods delegate to the SDK. Otherwise a stub is compiled and isAuthSupported is NO.
 */

#import <React/RCTBridgeModule.h>
#import <os/log.h>

#if __has_include(<SalesforceSDKCore/SFUserAccountManager.h>)
#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/SFOAuthCredentials.h>
#import <SalesforceSDKCore/SalesforceSDKManager.h>
#define HAS_SALESFORCE_SDK 1
#endif

@interface EmployeeAgentAuthBridge : NSObject <RCTBridgeModule>
@end

@implementation EmployeeAgentAuthBridge

RCT_EXPORT_MODULE(EmployeeAgentAuthBridge);

+ (BOOL)requiresMainQueueSetup {
  return NO;
}

#if HAS_SALESFORCE_SDK

/// Log the full OAuth error to the unified system log. The visible failures
/// ("invalid client credentials" / `invalid_client_id`) are connected-app/bootconfig
/// mismatches; NSError.userInfo carries the exact server error + description that the
/// generic localizedDescription drops. Visible in Console.app / Xcode under category
/// "bridge-diagnostics".
- (void)logAuthError:(NSString *)phase error:(NSError *)error {
  os_log_t log = os_log_create("com.salesforce.reactagentforce", "bridge-diagnostics");
  os_log_error(log, "[EmployeeAgentAuthBridge] %{public}@ FAILED → domain: %{public}@, code: %ld, desc: %{public}@, userInfo: %{public}@",
               phase,
               error.domain ?: @"<none>",
               (long)error.code,
               error.localizedDescription ?: @"<none>",
               error.userInfo ?: @{});
}

/// Build a richer rejection message that includes the underlying OAuth error so the
/// JS catch handler (and the customer's logs) sees the real cause, not just a generic line.
- (NSString *)detailedAuthMessage:(NSString *)fallback error:(NSError *)error {
  NSString *desc = error.localizedDescription ?: fallback;
  return [NSString stringWithFormat:@"%@ (domain=%@ code=%ld)", desc, error.domain ?: @"?", (long)error.code];
}

- (NSDictionary *)credentialsDictionaryFromUserAccount:(SFUserAccount *)userAccount {
  SFOAuthCredentials *creds = userAccount.credentials;
  if (!creds || !creds.accessToken) {
    return nil;
  }
  NSString *instanceUrl = creds.instanceUrl.absoluteString ?: @"";
  NSString *loginUrl = [NSString stringWithFormat:@"%@://%@", creds.protocol ?: @"https", creds.domain ?: @""];
  return @{
    @"instanceUrl": instanceUrl,
    @"organizationId": creds.organizationId ?: @"",
    @"userId": creds.userId ?: @"",
    @"accessToken": creds.accessToken ?: @"",
    @"refreshToken": (creds.refreshToken ?: [NSNull null]),
    @"loginUrl": loginUrl,
  };
}

RCT_EXPORT_METHOD(isAuthSupported:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  resolve(@YES);
}

RCT_EXPORT_METHOD(getAuthCredentials:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  SFUserAccount *currentUser = [SFUserAccountManager sharedInstance].currentUser;
  NSDictionary *creds = [self credentialsDictionaryFromUserAccount:currentUser];
  resolve(creds ?: [NSNull null]);
}

RCT_EXPORT_METHOD(refreshAuthCredentials:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  SFUserAccount *currentUser = [SFUserAccountManager sharedInstance].currentUser;
  if (!currentUser || !currentUser.credentials.refreshToken.length) {
    reject(@"NO_SESSION", @"No logged-in user or refresh token available.", nil);
    return;
  }
  [[SFUserAccountManager sharedInstance] refreshCredentials:currentUser.credentials
                                                completion:^(SFOAuthInfo *authInfo, SFUserAccount *userAccount) {
    NSDictionary *creds = [self credentialsDictionaryFromUserAccount:userAccount];
    if (creds) {
      resolve(creds);
    } else {
      reject(@"REFRESH_FAILED", @"Could not read credentials after refresh.", nil);
    }
  }
                                                   failure:^(SFOAuthInfo *authInfo, NSError *error) {
    [self logAuthError:@"refresh" error:error];
    reject(@"REFRESH_FAILED", [self detailedAuthMessage:@"Token refresh failed." error:error], error);
  }];
}

RCT_EXPORT_METHOD(login:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  dispatch_async(dispatch_get_main_queue(), ^{
    [[SFUserAccountManager sharedInstance] loginWithCompletion:^(SFOAuthInfo *authInfo, SFUserAccount *userAccount) {
      [SFUserAccountManager sharedInstance].currentUser = userAccount;
      NSDictionary *creds = [self credentialsDictionaryFromUserAccount:userAccount];
      if (creds) {
        resolve(creds);
      } else {
        reject(@"LOGIN_FAILED", @"Could not read credentials after login.", nil);
      }
    } failure:^(SFOAuthInfo *authInfo, NSError *error) {
      [self logAuthError:@"login" error:error];
      reject(@"LOGIN_FAILED", [self detailedAuthMessage:@"Login failed." error:error], error);
    }];
  });
}

RCT_EXPORT_METHOD(logout:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  __block id observerRef;
  id observer = [[NSNotificationCenter defaultCenter]
      addObserverForName:kSFNotificationUserDidLogout
      object:nil
      queue:[NSOperationQueue mainQueue]
      usingBlock:^(NSNotification *note) {
        [[NSNotificationCenter defaultCenter] removeObserver:observerRef];
        resolve(nil);
      }];
  observerRef = observer;
  dispatch_async(dispatch_get_main_queue(), ^{
    [[SFUserAccountManager sharedInstance] logout];
  });
}

#else

// Stub when Salesforce Mobile SDK is not linked (Service Agent–only apps).

RCT_EXPORT_METHOD(isAuthSupported:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  resolve(@NO);
}

RCT_EXPORT_METHOD(getAuthCredentials:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  resolve([NSNull null]);
}

RCT_EXPORT_METHOD(refreshAuthCredentials:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  reject(@"NOT_AVAILABLE", @"Token refresh requires Salesforce Mobile SDK.", nil);
}

RCT_EXPORT_METHOD(login:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  reject(@"NOT_AVAILABLE", @"Employee Agent auth requires Salesforce Mobile SDK. Use pod 'ReactNativeAgentforce/WithMobileSDK' and add the Mobile SDK to your app.", nil);
}

RCT_EXPORT_METHOD(logout:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  resolve(nil);
}

#endif

@end
