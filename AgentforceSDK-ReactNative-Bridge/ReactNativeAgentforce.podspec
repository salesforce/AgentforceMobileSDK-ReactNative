# React Native autolinking discovers podspecs at the npm package root.
# The sample's existing manual Podfile continues to use ios/ReactNativeAgentforce.podspec.
source_prefix = "ios/"
eval(File.read(File.join(__dir__, "ReactNativeAgentforce.podspec.rb")), binding, File.join(__dir__, "ReactNativeAgentforce.podspec.rb"))
