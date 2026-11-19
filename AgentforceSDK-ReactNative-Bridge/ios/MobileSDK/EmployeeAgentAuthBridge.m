/*
 * Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 *
 * React Native bridge for Employee Agent auth via Salesforce Mobile SDK.
 * Compiled only by the WithMobileSDK CocoaPods subspec. Service Agent and
 * SwiftPM builds omit this module; the JavaScript API handles its absence.
 */

#import <React/RCTBridgeModule.h>

#import <SalesforceSDKCore/SFUserAccountManager.h>
#import <SalesforceSDKCore/SFOAuthCredentials.h>
#import <SalesforceSDKCore/SalesforceSDKManager.h>

@interface EmployeeAgentAuthBridge : NSObject <RCTBridgeModule>
@end

@implementation EmployeeAgentAuthBridge

RCT_EXPORT_MODULE(EmployeeAgentAuthBridge);

+ (BOOL)requiresMainQueueSetup {
  return NO;
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
    reject(@"REFRESH_FAILED", error.localizedDescription ?: @"Token refresh failed.", error);
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
      reject(@"LOGIN_FAILED", error.localizedDescription ?: @"Login failed.", error);
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

@end
