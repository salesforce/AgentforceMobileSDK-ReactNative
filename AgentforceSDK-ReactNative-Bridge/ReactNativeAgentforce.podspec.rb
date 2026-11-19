require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))
sdk_root = File.expand_path('../../..', __dir__)
local_sdk = %w[AgentforceSDK AgentforceService AgentforceVoice].all? do |name|
  File.file?(File.join(sdk_root, "#{name}.podspec"))
end

Pod::Spec.new do |s|
  s.name          = "ReactNativeAgentforce"
  s.version       = package["version"]
  s.summary       = "Agentforce React Native bridge"
  s.description   = package["description"]
  s.homepage      = "https://github.com/salesforce/AgentforceMobileSDK-ReactNative"
  s.license       = "Apache-2.0"
  s.author        = "Salesforce"
  s.source        = { :git => "https://github.com/salesforce/AgentforceMobileSDK-ReactNative.git", :tag => "v#{s.version}" }
  s.requires_arc  = true
  s.platforms     = { :ios => "17.0" }
  s.swift_version = "5.0"

  s.default_subspec = "Core"

  s.subspec "Core" do |core|
    core.source_files = [
      "#{source_prefix}Agentforce/**/*.{h,m,swift}",
      "#{source_prefix}ServiceAgent/**/*.{h,m,swift}"
    ]
    core.dependency "React-Core"
    if local_sdk
      %w[AgentforceSDK AgentforceService AgentforceVoice].each do |name|
        core.dependency name
      end
      core.dependency "SharedUI/Binary", "~> 1.5", ">= 1.5.11"
    else
      core.dependency "AgentforceSDK", "264.1.0"
      core.dependency "AgentforceService", "264.1.0"
      core.dependency "AgentforceVoice", "264.1.0"
      core.dependency "SharedUI", "1.6.10"
    end
  end

  s.subspec "WithMobileSDK" do |mobile|
    mobile.source_files = "#{source_prefix}MobileSDK/**/*.{h,m,swift}"
    mobile.dependency "ReactNativeAgentforce/Core"
    mobile.dependency "SalesforceSDKCore"
  end
end
