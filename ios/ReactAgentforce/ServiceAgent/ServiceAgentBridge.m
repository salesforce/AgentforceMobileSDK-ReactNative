/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 */

#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(AgentforceModule, NSObject)

RCT_EXTERN_METHOD(configure:(NSString *)serviceApiURL
                  organizationId:(NSString *)organizationId
                  esDeveloperName:(NSString *)esDeveloperName
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(launchConversation:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(isConfigured:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

@end

