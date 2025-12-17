Pod::Spec.new do |s|
  s.name = 'Messaging-InApp-Core'
  s.version = '1.9.3-RC7'
  s.summary = 'Service Messaging Infrastructure Client Core Framework'
  s.homepage = 'https://salesforce.com'
  s.license = { :type => 'Salesforce', :text => 'Copyright (c) Salesforce' }
  s.author = { 'Salesforce' => 'developer@salesforce.com' }
  s.source = { :http => 'file://' + File.expand_path('SMIClientCore.xcframework.zip', __dir__) }
  s.ios.deployment_target = '16.0'
  s.vendored_frameworks = 'SMIClientCore.xcframework'
end