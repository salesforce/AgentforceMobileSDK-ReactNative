# Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
# React Native bridge for Agentforce SDK – iOS podspec
#
# Consumers: add to your app Podfile:
#   pod 'ReactNativeAgentforce', :path => '../node_modules/@salesforce/react-native-agentforce/ios'
#
# Your app must also include the Agentforce iOS SDK (and for Employee Agent, the
# Salesforce Mobile SDK). See README for details.

require "json"

package = JSON.parse(File.read(File.join(__dir__, "../package.json")))

Pod::Spec.new do |s|
  s.name         = "ReactNativeAgentforce"
  s.version      = package["version"]
  s.summary      = "Agentforce React Native bridge"
  s.description  = package["description"]
  s.homepage     = "https://github.com/salesforce/AgentforceMobileSDK-ReactNative"
  s.license      = "Apache-2.0"
  s.author       = "Salesforce"
  s.source       = { :git => "https://github.com/salesforce/AgentforceMobileSDK-ReactNative.git", :tag => "v#{s.version}" }
  s.requires_arc = true
  s.platforms    = { :ios => "17.0" }
  s.swift_version = "5.0"

  # Default: Service Agent (no Mobile SDK required). Use subspec 'WithMobileSDK' for Employee Agent auth.
  s.default_subspec = "Core"

  s.subspec "Core" do |core|
    core.source_files = [
      "Agentforce/**/*.{h,m,swift}",
      "ServiceAgent/**/*.{h,m,swift}"
    ]
    core.dependency "React-Core"
    core.dependency "AgentforceSDK"
    core.dependency "AgentforceVoice", "2.5.2"
    # AgentforceSDK 17.31.6 (262.1) depends on SharedUI ('~> 1'); declare it so
    # this target can resolve the design-system module.
    core.dependency "SharedUI", "1.3.1"
  end

  # Optional: add for Employee Agent auth (OAuth via Salesforce Mobile SDK).
  # Use: pod 'ReactNativeAgentforce/WithMobileSDK' in your Podfile.
  s.subspec "WithMobileSDK" do |mobile|
    mobile.dependency "ReactNativeAgentforce/Core"
    mobile.dependency "SalesforceSDKCore"
  end
end
