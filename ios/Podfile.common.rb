# Shared Podfile logic for Service and Employee agents.
# Required by Podfile.service and Podfile.employee.
# Service Agent dependencies are a subset of Employee Agent dependencies.

require File.join(File.dirname(`node --print "require.resolve('react-native/package.json')"`), "scripts/react_native_pods")

def shared_pods
  source 'https://github.com/forcedotcom/SalesforceMobileSDK-iOS-Specs.git'
  source 'https://github.com/livekit/podspecs.git'
  source 'https://cdn.cocoapods.org/'

  $config = use_native_modules!

  use_react_native!(
    :path => $config[:reactNativePath],
    :app_path => "#{Pod::Config.instance.installation_root}/.."
  )

  pod 'AgentforceSDK', '15.7.6'
  pod 'AgentforceVoice'
  pod 'Messaging-InApp-Core', '> 1.10.0'

  # JWTKit is required by AgentforceService but not resolved automatically
  pod 'JWTKit'

  # LiveKit is needed for both Service and Employee agents
  pod 'LiveKitClient' # Required so CocoaPods looks in the correct source location

  # AgentforceService links to Crypto.framework at runtime; SwiftCrypto provides it (avoids dyld "Library not loaded: Crypto.framework").
  pod 'SwiftCrypto', '~> 3.15'

  pod 'DequeModule'
  pod 'InternalCollectionsUtilities'
  pod 'OrderedCollections'

  pod 'Logging', '1.4.0'

  pod "swift-markdown-ui", :git => 'https://github.com/salesforce-misc/swift-markdown-ui.git', :branch => 'main'
  pod "cmark_gfm", :git => 'https://github.com/salesforce-misc/swift-markdown-ui.git', :branch => 'main'
end

def common_pre_install(installer)
  installer.pod_targets.each do |pod|
    if pod.name.eql?('RNReanimated')
      def pod.build_type
        Pod::BuildType.static_library
      end
    end
  end
end

def common_post_install(installer)
  # Create symlink from Pods/boost/boost to Homebrew boost headers
  # This ensures React Native uses local Homebrew installation instead of downloading
  boost_pod_path = File.join(installer.sandbox.root, 'boost')
  boost_headers_symlink = File.join(boost_pod_path, 'boost')

  if File.directory?(boost_pod_path)
    brew_boost_prefix = `brew --prefix boost 2>/dev/null`.strip
    if !brew_boost_prefix.empty? && File.directory?(brew_boost_prefix)
      brew_boost_headers = File.join(brew_boost_prefix, 'include', 'boost')

      # Remove any existing boost directory/symlink
      FileUtils.rm_rf(boost_headers_symlink) if File.exist?(boost_headers_symlink)

      # Create symlink to Homebrew boost headers
      File.symlink(brew_boost_headers, boost_headers_symlink)
      Pod::UI.puts "✅ Linked Pods/boost/boost -> #{brew_boost_headers}".green
    else
      Pod::UI.warn "⚠️  Homebrew Boost not found. Run: brew install boost"
    end
  end

  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
      config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
      config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
      config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
      config.build_settings['SWIFT_COMPILATION_MODE'] = 'wholemodule'
      config.build_settings['VALIDATE_WORKSPACE'] = 'YES'
      config.build_settings['GCC_PRECOMPILE_PREFIX_HEADER'] = 'NO'

      if defined?(target.product_type) && target.product_type == "com.apple.product-type.framework"
        config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
      end
    end
  end

  $config = use_native_modules!
  react_native_post_install(
    installer,
    $config[:reactNativePath],
    :mac_catalyst_enabled => false
  )

  # Ensure React-Core headers are on project HEADER_SEARCH_PATHS so app targets
  # that inherit from project get them (fixes 'React/RCTBridgeDelegate.h' file not found).
  add_react_core_header_paths(installer)

  # Make ServiceAgent target explicitly depend on Pods-ServiceAgent so Pods build first
  # (fixes 'React/RCTBridgeDelegate.h' file not found when building in parallel).
  add_pods_target_dependency(installer)
end

def add_pods_target_dependency(installer)
  # Handle both ServiceAgent and EmployeeAgent targets
  %w[ServiceAgent EmployeeAgent].each do |app_name|
    aggregate = installer.aggregate_targets.find { |t| t.name == "Pods-#{app_name}" }
    next unless aggregate

    user_project = aggregate.user_project
    pods_project = installer.pods_project
    app_target = user_project.targets.find { |t| t.name == app_name }
    pods_target = pods_project.targets.find { |t| t.name == "Pods-#{app_name}" }
    next unless app_target && pods_target

    # Skip if dependency already exists
    next if app_target.dependencies.any? { |d|
      d.target_proxy && d.target_proxy.remote_info == "Pods-#{app_name}"
    }

    # Add Pods target as explicit dependency of app target
    ios_root = File.expand_path(Pod::Config.instance.installation_root)
    pods_xcodeproj_path = File.join(ios_root, 'Pods', 'Pods.xcodeproj')

    pods_ref = user_project.reference_for_path(pods_xcodeproj_path)
    unless pods_ref
      pods_ref = user_project.new_file(pods_xcodeproj_path)
      user_project.main_group << pods_ref unless user_project.main_group.children.include?(pods_ref)
    end

    proxy = user_project.new(Xcodeproj::Project::Object::PBXContainerItemProxy)
    proxy.container_portal = pods_ref.uuid
    proxy.remote_global_id_string = pods_target.uuid
    proxy.remote_info = "Pods-#{app_name}"
    proxy.proxy_type = '1'

    dep = user_project.new(Xcodeproj::Project::Object::PBXTargetDependency)
    dep.target_proxy = proxy
    app_target.dependencies << dep
    user_project.save

    Pod::UI.puts "✅ Added #{app_name} -> Pods-#{app_name} target dependency".green
  end
end

def add_react_core_header_paths(installer)
  react_core_headers = '"${PODS_CONFIGURATION_BUILD_DIR}/React-Core/React.framework/Headers"'
  installer.aggregate_targets.each do |aggregate|
    next unless aggregate.user_project
    aggregate.user_project.build_configurations.each do |config|
      paths = config.build_settings['HEADER_SEARCH_PATHS']
      next unless paths
      paths = paths.is_a?(Array) ? paths.join(' ') : paths.to_s
      next if paths.include?('React-Core/React.framework/Headers')
      config.build_settings['HEADER_SEARCH_PATHS'] = paths.strip + ' ' + react_core_headers
    end
    aggregate.user_project.save
    break
  end
end
