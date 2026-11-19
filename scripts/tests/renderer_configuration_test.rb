# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require 'open3'
require 'rbconfig'

class RendererConfigurationTest < Minitest::Test
  SAMPLE_ROOT = File.expand_path('../..', __dir__)

  # Resolve the real shared Podfile and RNScreens podspec in isolated processes.
  # Record React Native setup without installing pods or modifying local projects.
  PROBE = <<~'RUBY'
    require 'cocoapods'
    require 'json'
    require File.expand_path('ios/Podfile.common.rb')

    class Pod::Podfile
      attr_reader :renderer_calls

      def plugin(*); end
      def prepare_react_native_project!; end

      def use_native_modules!
        record_renderer('autolink')
        { reactNativePath: File.expand_path('node_modules/react-native') }
      end

      def use_react_native!(**)
        record_renderer('react-native')
      end

      def record_renderer(phase)
        (@renderer_calls ||= []) << {
          target: current_target_definition.name,
          phase: phase,
          new_arch: NewArchitectureHelper.new_arch_enabled
        }
      end
    end

    path = File.expand_path(ARGV.fetch(0))
    podfile = Pod::Podfile.from_ruby(path, File.read(path))
    screens = Pod::Specification.from_file(File.expand_path('node_modules/react-native-screens/RNScreens.podspec'))
    puts JSON.generate(calls: podfile.renderer_calls, screens: screens.to_hash,
      platforms: podfile.target_definitions.values.reject(&:abstract?).map { |target| target.platform.deployment_target.to_s })
  RUBY

  def test_all_podfiles_build_navigation_for_the_apps_bridge_renderer
    %w[Podfile.employee Podfile.service].each do |podfile|
      [nil, '0', '1'].each do |inherited_arch|
        output, errors, status = Open3.capture3(
          { 'RCT_NEW_ARCH_ENABLED' => inherited_arch },
          RbConfig.ruby, '-e', PROBE, "ios/#{podfile}", chdir: SAMPLE_ROOT
        )
        assert status.success?, "#{podfile}, inherited architecture #{inherited_arch.inspect}: #{errors}"
        result = JSON.parse(output.lines.last)
        targets = podfile == 'Podfile.service' ? %w[ServiceAgent] : %w[ServiceAgent EmployeeAgent]
        assert_equal Array.new(targets.length, '18.0'), result.fetch('platforms')
        assert_equal targets.product(%w[autolink react-native]), result.fetch('calls').map { |call|
          [call.fetch('target'), call.fetch('phase')]
        }
        result.fetch('calls').each do |call|
          refute call.fetch('new_arch'), "#{podfile}: #{call}"
        end
        # RNScreens excludes its Paper view factories when this macro is defined,
        # leaving RCTViewManager to return a plain RCTView for navigation headers.
        refute_includes result.fetch('screens').to_json, '-DRCT_NEW_ARCH_ENABLED'
        refute_includes result.fetch('screens').to_json, 'common/cpp'
      end
    end
  end
end
