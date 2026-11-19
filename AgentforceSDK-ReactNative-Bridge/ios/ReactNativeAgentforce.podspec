# Existing manual Podfile entry point. Keep source paths relative to ios/.
source_prefix = ""
eval(File.read(File.join(__dir__, "../ReactNativeAgentforce.podspec.rb")), binding, File.join(__dir__, "../ReactNativeAgentforce.podspec.rb"))
