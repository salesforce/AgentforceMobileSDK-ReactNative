# Copyright (c) 2024-present, salesforce.com, inc. All rights reserved.
# React Native bridge for Agentforce SDK – iOS podspec
#
# Consumers: add to your app Podfile:
#   pod 'ReactNativeAgentforce', :path => '../node_modules/react-native-agentforce/ios'
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
  s.homepage     = "https://git.soma.salesforce.com/robertson-waweru/AgentforceSDK-ReactNative-Bridge"
  s.license      = "BSD-3-Clause"
  s.author       = "Salesforce"
  s.source       = { :git => "https://git.soma.salesforce.com/robertson-waweru/AgentforceSDK-ReactNative-Bridge.git", :tag => "v#{s.version}" }
  s.requires_arc = true
  s.platforms    = { :ios => "15.0" }
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
  end

  # Optional: add for Employee Agent auth (OAuth via Salesforce Mobile SDK).
  # Use: pod 'ReactNativeAgentforce/WithMobileSDK' in your Podfile.
  s.subspec "WithMobileSDK" do |mobile|
    mobile.dependency "ReactNativeAgentforce/Core"
    mobile.dependency "SalesforceSDKCore"
  end
end
