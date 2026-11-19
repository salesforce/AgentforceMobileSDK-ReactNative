/* Copyright (c) 2024-present, salesforce.com, inc. All rights reserved. */

#import "SceneDelegate.h"
#import "AppDelegate.h"

@implementation SceneDelegate

- (void)scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
                 options:(UISceneConnectionOptions *)connectionOptions
{
  if (![scene isKindOfClass:[UIWindowScene class]]) {
    return;
  }

  self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
  AppDelegate *appDelegate = (AppDelegate *)UIApplication.sharedApplication.delegate;
  // Keep the app delegate's window available to Mobile SDK and existing callers.
  appDelegate.window = self.window;
  [appDelegate proceedToApp];
}

- (void)sceneDidDisconnect:(UIScene *)scene
{
  AppDelegate *appDelegate = (AppDelegate *)UIApplication.sharedApplication.delegate;
  if (appDelegate.window == self.window) {
    appDelegate.window = nil;
  }
  self.window = nil;
}

@end
