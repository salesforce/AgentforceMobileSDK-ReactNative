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

#import "LandingViewController.h"
#import "AppDelegate.h"

@implementation LandingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Set background color
    self.view.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.97 alpha:1.0];
    
    // Create main container view
    UIView *containerView = [[UIView alloc] init];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:containerView];
    
    // Create title label
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Agentforce SDK";
    titleLabel.font = [UIFont systemFontOfSize:36 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor colorWithRed:0.051 green:0.765 blue:0.733 alpha:1.0];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:titleLabel];
    
    // Create subtitle label
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.text = @"React Native Demo";
    subtitleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightRegular];
    subtitleLabel.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.4 alpha:1.0];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:subtitleLabel];
    
    // Create description label
    UILabel *descriptionLabel = [[UILabel alloc] init];
    descriptionLabel.text = @"Welcome to the Agentforce SDK React Native integration. Tap the button below to launch the app.";
    descriptionLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    descriptionLabel.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    descriptionLabel.textAlignment = NSTextAlignmentCenter;
    descriptionLabel.numberOfLines = 0;
    descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:descriptionLabel];
    
    // Create launch button
    UIButton *launchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [launchButton setTitle:@"Launch App" forState:UIControlStateNormal];
    launchButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    [launchButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    launchButton.backgroundColor = [UIColor colorWithRed:0.051 green:0.765 blue:0.733 alpha:1.0];
    launchButton.layer.cornerRadius = 12;
    launchButton.translatesAutoresizingMaskIntoConstraints = NO;
    [launchButton addTarget:self action:@selector(launchButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [containerView addSubview:launchButton];
    
    // Add constraints for container view
    [NSLayoutConstraint activateConstraints:@[
        [containerView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [containerView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [containerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [containerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40],
    ]];
    
    // Add constraints for title label
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:containerView.topAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
    ]];
    
    // Add constraints for subtitle label
    [NSLayoutConstraint activateConstraints:@[
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
    ]];
    
    // Add constraints for description label
    [NSLayoutConstraint activateConstraints:@[
        [descriptionLabel.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:32],
        [descriptionLabel.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [descriptionLabel.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
    ]];
    
    // Add constraints for launch button
    [NSLayoutConstraint activateConstraints:@[
        [launchButton.topAnchor constraintEqualToAnchor:descriptionLabel.bottomAnchor constant:40],
        [launchButton.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [launchButton.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
        [launchButton.heightAnchor constraintEqualToConstant:56],
        [launchButton.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor],
    ]];
}

- (void)launchButtonTapped:(UIButton *)sender {
    // Disable button to prevent multiple taps
    sender.enabled = NO;
    sender.alpha = 0.6;
    
    // Call AppDelegate method to proceed with login and React Native setup
    if (self.appDelegate) {
        [self.appDelegate proceedToApp];
    }
}

@end

