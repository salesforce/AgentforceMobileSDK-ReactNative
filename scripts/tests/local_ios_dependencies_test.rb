# frozen_string_literal: true

require 'minitest/autorun'
require 'cocoapods'
require 'fileutils'
require 'tmpdir'

class LocalIOSDependenciesTest < Minitest::Test
  SAMPLE_ROOT = File.expand_path('../..', __dir__)
  MODULES = %w[AgentforceSDK AgentforceService AgentforceVoice].freeze

  def setup
    @root = Dir.mktmpdir('rn-ios-dependencies-')
    @sample = File.join(@root, 'react-native/sdk')
    @bridge = File.join(@sample, 'AgentforceSDK-ReactNative-Bridge')
    FileUtils.mkdir_p(File.join(@sample, 'ios'))
    FileUtils.mkdir_p(@bridge)
    FileUtils.cp(File.join(SAMPLE_ROOT, 'AgentforceSDK-ReactNative-Bridge/package.json'), @bridge)
    FileUtils.cp(File.join(SAMPLE_ROOT, 'AgentforceSDK-ReactNative-Bridge/ReactNativeAgentforce.podspec.rb'), @bridge)
    @common = File.join(@sample, 'ios/Podfile.common.rb')
    FileUtils.cp(File.join(SAMPLE_ROOT, 'ios/Podfile.common.rb'), @common)
  end

  def teardown
    FileUtils.rm_rf(@root)
  end

  def hooks
    harness = Class.new do
      attr_reader :pods

      def initialize; @pods = []; end
      def source(*); end
      def use_native_modules!; { reactNativePath: 'unused' }; end
      def use_react_native!(*); end
      def react_native_post_install(*); end
      def add_react_core_header_paths(*); end
      def add_pods_target_dependency(*); end
      def pod(*args); @pods << args; end
    end
    harness.class_eval(File.read(@common).lines.reject { |line| line.start_with?('require ') }.join, @common)
    harness.define_method(:add_react_core_header_paths) { |*| }
    harness.define_method(:add_pods_target_dependency) { |*| }
    harness.new
  end

  def bridge_dependencies
    # The published package entry point supplies its source prefix before eval.
    entry = File.join(@bridge, 'ReactNativeAgentforce.podspec')
    File.write(entry, "source_prefix = 'ios/'\neval(File.read(File.join(__dir__, 'ReactNativeAgentforce.podspec.rb')), binding, File.join(__dir__, 'ReactNativeAgentforce.podspec.rb'))\n")
    Pod::Specification.from_file(entry).subspec_by_name('ReactNativeAgentforce/Core').dependencies
  end

  def test_local_checkout_uses_local_modules_and_matching_binary_design_system
    MODULES.each { |name| File.write(File.join(@root, "#{name}.podspec"), '# Local spec') }
    runtime = hooks
    runtime.shared_pods
    MODULES.each do |name|
      assert_equal [[name, { path: @root }]], runtime.pods.select { |pod| pod.first == name }
      dependency = bridge_dependencies.find { |item| item.name == name }
      assert_equal '>= 0', dependency.requirement.to_s
    end
    assert_includes runtime.pods.map(&:first), 'SharedUI/Binary'
    assert_includes runtime.pods.map(&:first), 'SLDSIcons/Binary'
    assert_includes bridge_dependencies.map(&:name), 'SharedUI/Binary'
    refute_includes runtime.pods.map(&:first), 'SharedUI'
  end

  def test_standalone_checkout_preserves_published_dependencies
    runtime = hooks
    runtime.shared_pods
    MODULES.each do |name|
      assert_includes runtime.pods, [name, '264.0.0']
      assert_equal '= 264.0.0', bridge_dependencies.find { |item| item.name == name }.requirement.to_s
    end
    assert_includes runtime.pods, ['SharedUI', '1.6.10']
    refute_includes bridge_dependencies.map(&:name), 'SharedUI/Binary'
  end

  def test_incomplete_local_checkout_fails_without_published_fallback
    File.write(File.join(@root, 'AgentforceSDK.podspec'), '# Local spec')
    error = assert_raises(Pod::Informative) { hooks }
    assert_includes error.message, 'Incomplete local Agentforce SDK'
    assert_includes error.message, 'AgentforceService.podspec'
  end

  def test_post_install_raises_old_targets_without_lowering_newer_requirements
    configs = %w[13.0 18.0 19.0].map { |version|
      Struct.new(:build_settings).new({ 'IPHONEOS_DEPLOYMENT_TARGET' => version })
    }
    target = Struct.new(:build_configurations).new(configs)
    installer = Struct.new(:pods_project).new(Struct.new(:targets).new([target]))
    hooks.common_post_install(installer)
    assert_equal %w[18.0 18.0 19.0], configs.map { |config| config.build_settings.fetch('IPHONEOS_DEPLOYMENT_TARGET') }
  end
end
