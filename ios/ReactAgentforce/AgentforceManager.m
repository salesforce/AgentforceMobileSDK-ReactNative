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

#import "AgentforceManager.h"
#import "ReactAgentforce-Swift.h"
#import <React/RCTLog.h>
#import "AppDelegate.h"
#import "LandingViewController.h"

@interface AgentforceManager()
@property (nonatomic, strong) AgentforceClientManager *agentforceClient;
@end

@implementation AgentforceManager

RCT_EXPORT_MODULE();

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

- (NSArray<NSString *> *)supportedEvents
{
    return @[@"agentforceNavigation"];
}

- (void)emitNavigationEvent:(NSDictionary *)eventData
{
    [self sendEventWithName:@"agentforceNavigation" body:eventData];
}

RCT_EXPORT_METHOD(initializeAgentforce:(NSDictionary *)config
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            NSArray *agents = config[@"agents"];
            NSString *orgId = config[@"orgId"];
            NSString *endpoint = config[@"endpoint"];

            if (!agents || !orgId || !endpoint) {
                reject(@"INVALID_CONFIG", @"Missing required configuration parameters", nil);
                return;
            }

            self.agentforceClient = [[AgentforceClientManager alloc] initWithEventEmitter:self];
            [self.agentforceClient initializeWithAgents:agents
                                                  orgId:orgId
                                               endpoint:endpoint
                                             completion:^(NSError * _Nullable error) {
                if (error) {
                    reject(@"INIT_ERROR", error.localizedDescription, error);
                } else {
                    resolve(@{@"success": @YES});
                }
            }];
        } @catch (NSException *exception) {
            reject(@"INIT_EXCEPTION", exception.reason, nil);
        }
    });
}

RCT_EXPORT_METHOD(presentAgentforceChatView:(NSString *)agentId
                  userContext:(NSString *)userContext
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!self.agentforceClient) {
                reject(@"NOT_INITIALIZED", @"AgentforceClient not initialized. Call initializeAgentforce first.", nil);
                return;
            }

            [self.agentforceClient presentChatViewWithAgentId:agentId
                                                   userContext:userContext
                                                    completion:^(NSError * _Nullable error) {
                if (error) {
                    reject(@"PRESENT_ERROR", error.localizedDescription, error);
                } else {
                    resolve(@{@"success": @YES});
                }
            }];
        } @catch (NSException *exception) {
            reject(@"PRESENT_EXCEPTION", exception.reason, nil);
        }
    });
}

RCT_EXPORT_METHOD(dismissAgentforceChatView:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (!self.agentforceClient) {
                reject(@"NOT_INITIALIZED", @"AgentforceClient not initialized.", nil);
                return;
            }

            [self.agentforceClient dismissChatViewWithCompletion:^(NSError * _Nullable error) {
                if (error) {
                    reject(@"DISMISS_ERROR", error.localizedDescription, error);
                } else {
                    resolve(@{@"success": @YES});
                }
            }];
        } @catch (NSException *exception) {
            reject(@"DISMISS_EXCEPTION", exception.reason, nil);
        }
    });
}

RCT_EXPORT_METHOD(showLandingPage:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
            if (appDelegate && appDelegate.window) {
                LandingViewController *landingVC = [[LandingViewController alloc] initWithNibName:nil bundle:nil];
                landingVC.appDelegate = appDelegate;
                appDelegate.window.rootViewController = landingVC;
                resolve(@{@"success": @YES});
            } else {
                reject(@"NO_APP_DELEGATE", @"Unable to access AppDelegate", nil);
            }
        } @catch (NSException *exception) {
            reject(@"SHOW_LANDING_EXCEPTION", exception.reason, nil);
        }
    });
}

@end