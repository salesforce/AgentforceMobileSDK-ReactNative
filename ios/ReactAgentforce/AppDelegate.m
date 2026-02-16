/*
 Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
 
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

#import "AppDelegate.h"
#import <React/RCTBundleURLProvider.h>
#import <React/RCTBridge.h>
#import <React/RCTRootView.h>
#import <SalesforceReact/SalesforceReactSDKManager.h>

@interface AppDelegate ()
@property (nonatomic, strong) RCTBridge *bridge;
@property (nonatomic, strong) NSDictionary *launchOptions;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  // Initialize Salesforce Mobile SDK (required for Employee Agent auth)
  [SalesforceReactSDKManager initializeSDK];

  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  self.launchOptions = launchOptions;
  
  // Initialize React Native bridge in advance (but don't show it yet)
  self.bridge = [[RCTBridge alloc] initWithDelegate:self launchOptions:launchOptions];
  
  // For Service Agent mode, go directly to React Native (no authentication needed)
  [self proceedToApp];
  
  return YES;
}

- (void)proceedToApp
{
  // Create React Native root view
  RCTRootView *rootView = [[RCTRootView alloc] initWithBridge:self.bridge
                                                    moduleName:@"ReactAgentforce"
                                             initialProperties:nil];
  
  rootView.backgroundColor = [[UIColor alloc] initWithRed:1.0f green:1.0f blue:1.0f alpha:1];
  
  // Create root view controller
  UIViewController *rootViewController = [UIViewController new];
  rootViewController.view = rootView;
  
  // Set as root and animate if transitioning from another screen
  if (self.window.rootViewController) {
    // Animate transition
    [UIView transitionWithView:self.window
                      duration:0.3
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                      self.window.rootViewController = rootViewController;
                    }
                    completion:nil];
  } else {
    // Initial setup
    self.window.rootViewController = rootViewController;
  }
  
  [self.window makeKeyAndVisible];
}

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge
{
  return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:@"index"];
}

@end
