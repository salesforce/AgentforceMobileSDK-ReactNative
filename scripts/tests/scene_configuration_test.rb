# frozen_string_literal: true

require 'minitest/autorun'
require 'plist'
require 'xcodeproj'
require 'tmpdir'
require 'open3'

class SceneConfigurationTest < Minitest::Test
  IOS_ROOT = File.expand_path('../../ios', __dir__)

  def test_both_targets_compile_the_delegate_declared_by_their_scene_manifest
    Dir.mktmpdir('rn-scene-project-') do |root|
      output, status = Open3.capture2e('xcodegen', 'generate', '--spec', File.join(IOS_ROOT, 'project.yml'), '--project', root)
      assert status.success?, output
      project = Xcodeproj::Project.open(File.join(root, 'ReactAgentforce.xcodeproj'))
      %w[ServiceAgent EmployeeAgent].each do |name|
        target = project.targets.find { |item| item.name == name }
        refute_nil target
        target.build_configurations.each do |config|
          assert_equal '18.0', config.build_settings.fetch('IPHONEOS_DEPLOYMENT_TARGET')
        end
        info = Plist.parse_xml(File.join(IOS_ROOT, name, 'Info.plist'))
        manifest = info.fetch('UIApplicationSceneManifest')
        assert_equal false, manifest.fetch('UIApplicationSupportsMultipleScenes')
        configuration = manifest.fetch('UISceneConfigurations').fetch('UIWindowSceneSessionRoleApplication').first
        assert_equal 'SceneDelegate', configuration.fetch('UISceneDelegateClassName')

        sources = target.source_build_phase.files_references
        assert_equal 1, sources.count { |file| file.path.end_with?('SceneDelegate.m') }
        delegate = sources.find { |file| file.path.end_with?('AppDelegate.m') }
        expected_directory = name == 'ServiceAgent' ? 'Shared' : 'EmployeeAgent'
        assert_equal expected_directory, File.basename(delegate.real_path.dirname)
      end
    end
  end
end
