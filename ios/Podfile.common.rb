# Shared Podfile logic for Service and Employee agents.
# Required by Podfile.service and Podfile.employee.
# Service Agent dependencies are a subset of Employee Agent dependencies.

# Both app delegates create an RCTBridge/RCTRootView (Paper). Keep native view
# managers on that renderer too; Fabric-only factories cannot serve this host.
# Set this before autolinking and podspec evaluation, including in CI shells.
ENV['RCT_NEW_ARCH_ENABLED'] = '0'

require File.join(File.dirname(`node --print "require.resolve('react-native/package.json')"`), "scripts/react_native_pods")

AGENTFORCE_MONOREPO_ROOT = File.expand_path('../../..', __dir__)
AGENTFORCE_PODSPEC_FILES = %w[
  AgentforceSDK.podspec
  AgentforceService.podspec
  AgentforceVoice.podspec
]
AGENTFORCE_PRESENT_PODS = AGENTFORCE_PODSPEC_FILES.select { |podspec| File.file?(File.join(AGENTFORCE_MONOREPO_ROOT, podspec)) }
if AGENTFORCE_PRESENT_PODS.any? && AGENTFORCE_PRESENT_PODS != AGENTFORCE_PODSPEC_FILES
  raise Pod::Informative, "Incomplete local Agentforce SDK; missing #{(AGENTFORCE_PODSPEC_FILES - AGENTFORCE_PRESENT_PODS).join(', ')}. Restore the SDK checkout before installing pods."
end
AGENTFORCE_LOCAL_PODS = AGENTFORCE_PRESENT_PODS.any?

def shared_pods
  source 'https://github.com/forcedotcom/SalesforceMobileSDK-iOS-Specs.git'
  source 'https://github.com/livekit/podspecs.git'
  # Hosts the Messaging-Multimedia-Core podspec (vends SMIMultimediaCore.framework).
  # Not mirrored on the CDN, so the source must be declared explicitly for the
  # AgentforceVoice service-voice multimedia dependency to resolve.
  source 'https://github.com/Salesforce-Async-Messaging/podspecs.git'
  source 'https://cdn.cocoapods.org/'

  $config = use_native_modules!

  use_react_native!(
    :path => $config[:reactNativePath],
    :app_path => "#{Pod::Config.instance.installation_root}/.."
  )

  # Resolve sibling podspecs when running from a combined source checkout.
  # Standalone copies fall back to the matching published release.
  if AGENTFORCE_LOCAL_PODS
    pod 'AgentforceSDK', :path => AGENTFORCE_MONOREPO_ROOT
    pod 'AgentforceService', :path => AGENTFORCE_MONOREPO_ROOT
    pod 'AgentforceVoice', :path => AGENTFORCE_MONOREPO_ROOT
  else
    pod 'AgentforceSDK', '264.1.0'
    pod 'AgentforceService', '264.1.0'
    pod 'AgentforceVoice', '264.1.0'
  end
  pod 'Messaging-InApp-Core', '~> 1.13.0'
  # Messaging-Multimedia-Core vends SMIMultimediaCore.framework, which
  # AgentforceVoice links at runtime (@rpath/SMIMultimediaCore.framework).
  # The AgentforceVoice podspec resolved from this Specs source declares only
  # AgentforceService/SalesforceLogging/SalesforceNetwork (not the Binary subspec
  # that the iOS SDK uses), so this transitive multimedia dep isn't pulled in and
  # the framework is never embedded — surfacing as a dyld "Library not loaded"
  # crash once Service Agent voice is enabled. Declare it explicitly so it's
  # installed and embedded.
  # Keep the Messaging family on the line required by AgentforceVoice 264.0.0.
  pod 'Messaging-Multimedia-Core', '~> 1.13.0'

  # JWTKit is required by AgentforceService but not resolved automatically
  pod 'JWTKit'

  # SharedUI provides the design-system module (Colors/Fonts/Dimensions).
  # Match the local SDK's Binary design-system subspecs when using local source.
  # Public standalone installs retain the paired published flat specs.
  if AGENTFORCE_LOCAL_PODS
    pod 'SharedUI/Binary', '~> 1.5', '>= 1.5.11'
    pod 'SLDSIcons/Binary'
  else
    pod 'SharedUI', '1.6.10'
    pod 'SLDSIcons', '1.2.7'
  end

  # Match AgentforceVoice and Messaging-Multimedia-Core on main (PR #125).
  pod 'LiveKitClient-XCFramework', '~> 2.16.0'

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
  repair_legacy_boost_installation(installer)
  installer.pod_targets.each do |pod|
    if pod.name.eql?('RNReanimated')
      def pod.build_type
        Pod::BuildType.static_library
      end
    end
  end
  patch_fmt_for_apple_clang(installer)
end

def repair_legacy_boost_installation(installer)
  boost = installer.pod_targets.find { |pod| pod.name == 'boost' }
  return unless boost && File.symlink?(File.join(installer.sandbox.root, 'boost/boost'))

  # Older post-install hooks replaced the entire header directory with a symlink.
  # Restore the pinned source and privacy resource through CocoaPods' downloader,
  # before header maps are generated. Do not alter the Homebrew installation.
  Pod::UI.puts 'Restoring the legacy Boost installation before generating header maps.'
  Pod::Installer::PodSourceInstaller.new(
    installer.sandbox, installer.podfile, { boost.platform => boost.specs }
  ).install!
  if File.symlink?(File.join(installer.sandbox.root, 'boost/boost'))
    raise Pod::Informative, 'Boost source still has the legacy layout after reinstalling; refresh the Boost pod cache.'
  end
  boost.file_accessors.each { |accessor| accessor.path_list.read_file_system }
end

def patch_fmt_for_apple_clang(installer)
  fmt = installer.pod_targets.find { |pod| pod.name == 'fmt' }
  return unless fmt && fmt.root_spec.version.to_s == '11.0.2'

  # fmt 11.0.2 enables consteval on Apple Clang 21+, which rejects its format
  # implementation. This release overwrites command-line FMT_USE_CONSTEVAL
  # definitions. Patch its detection before source locking, for all consumers.
  header = File.join(installer.sandbox.root, 'fmt/include/fmt/base.h')
  original = '#elif defined(__apple_build_version__) && __apple_build_version__ < 14000029L'
  patched = '#elif defined(__apple_build_version__) && (__apple_build_version__ < 14000029L || __apple_build_version__ >= 21000000L)'
  content = File.read(header)
  return if content.include?(patched)
  unless content.include?(original)
    raise Pod::Informative, 'Unexpected fmt 11.0.2 compiler detection; review the Apple Clang compatibility patch.'
  end

  mode = File.stat(header).mode
  begin
    File.chmod(mode | 0o200, header)
    File.write(header, content.sub(original, patched))
  ensure
    File.chmod(mode, header)
  end
end

def common_post_install(installer)
  # The patched Boost podspec prepares its Homebrew header link before CocoaPods
  # indexes sources. Preserve that layout here: replacing the tree invalidates
  # cached header and privacy-resource paths used when CocoaPods locks sources.
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = [
        Gem::Version.new(config.build_settings.fetch('IPHONEOS_DEPLOYMENT_TARGET', '0')),
        Gem::Version.new('18.0')
      ].max.to_s
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

    # Add Pods target as explicit dependency of app target
    ios_root = File.expand_path(Pod::Config.instance.installation_root)
    pods_xcodeproj_path = File.join(ios_root, 'Pods', 'Pods.xcodeproj')

    pods_ref = user_project.reference_for_path(pods_xcodeproj_path)
    unless pods_ref
      pods_ref = user_project.new_file(pods_xcodeproj_path)
      user_project.main_group << pods_ref unless user_project.main_group.children.include?(pods_ref)
    end

    # xcodeproj's new_file shares the app Products group with the subproject.
    # Xcode expects only PBXReferenceProxy children in a subproject's ProductGroup;
    # app PBXFileReferences there crash its project-save path (e.g. editing signing).
    # Repair older generated projects too, even if their dependencies already exist.
    reference = user_project.root_object.project_references.find { |ref| ref[:project_ref] == pods_ref }
    if reference && reference[:product_group] == user_project.products_group
      products = user_project.new(Xcodeproj::Project::Object::PBXGroup)
      products.name = 'Products'
      products.source_tree = '<group>'
      user_project.products_group.children.select { |child|
        child.isa == 'PBXReferenceProxy' && child.remote_ref.container_portal == pods_ref.uuid
      }.each do |child|
        user_project.products_group.children.delete(child)
        products.children << child
      end
      reference[:product_group] = products
      user_project.save
    end

    next if app_target.dependencies.any? { |d|
      d.target_proxy && d.target_proxy.remote_info == "Pods-#{app_name}"
    }

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
