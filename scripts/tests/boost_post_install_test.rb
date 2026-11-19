# frozen_string_literal: true

require 'minitest/autorun'
require 'cocoapods'
require 'fileutils'
require 'tmpdir'

class BoostPostInstallTest < Minitest::Test
  SAMPLE_ROOT = File.expand_path('../..', __dir__)

  def test_pre_install_restores_legacy_flattened_headers_before_indexing
    Dir.mktmpdir('boost-legacy-install-') do |root|
      sandbox = Pod::Sandbox.new(File.join(root, 'Pods'))
      pod_root = sandbox.root.join('boost')
      FileUtils.mkdir_p(pod_root)
      brew_headers = Pathname.new(root).join('brew/include/boost')
      FileUtils.mkdir_p(brew_headers)
      brew_header = brew_headers.join('version.hpp')
      brew_header.write('// Homebrew header must remain unchanged and writable')
      File.symlink(brew_headers, pod_root.join('boost'))
      spec = Pod::Specification.new do |s|
        s.name = 'boost'
        s.version = '1.84.0'
        s.source = { git: 'https://example.test/boost', tag: 'v1.84.0' }
        s.source_files = 'boost/**/*.{hpp,cpp}'
        s.header_mappings_dir = 'boost/boost'
        s.resource_bundles = { 'boost_privacy' => 'boost/PrivacyInfo.xcprivacy' }
      end
      accessor = Pod::Sandbox::FileAccessor.new(pod_root, spec.consumer(:ios))
      assert_empty accessor.headers # Match the stale cached file list from the broken install.
      source_installer = Pod::Installer::PodSourceInstaller.new(sandbox, Pod::Podfile.new, { ios: [spec] })
      target = Struct.new(:name, :root_spec, :file_accessors, :platform, :specs).new(
        'boost', spec, [accessor], Pod::Platform.new(:ios, '18.0'), [spec])
      installer = Struct.new(:sandbox, :pod_targets, :podfile).new(sandbox, [target], Pod::Podfile.new)
      hooks = Class.new
      common = File.read(File.join(SAMPLE_ROOT, 'ios/Podfile.common.rb'))
      hooks.class_eval(common.lines.reject { |line| line.start_with?('require ') }.join)
      downloads = 0
      download = lambda do |_request, destination, *_options|
        downloads += 1
        FileUtils.rm_rf(destination)
        header = destination.join('boost/preprocessor/control/expr_iif.hpp')
        FileUtils.mkdir_p(header.dirname)
        header.write('// Pinned source header')
        destination.join('boost/PrivacyInfo.xcprivacy').write('<plist/>')
        File.symlink(brew_headers, destination.join('boost/boost'))
        Struct.new(:checkout_options).new(nil)
      end
      # Exercise the real CocoaPods source installer; keep its downloader offline.
      Pod::Downloader.stub(:download, download) do
        hooks.new.common_pre_install(installer)
        assert_includes accessor.headers, pod_root.join('boost/preprocessor/control/expr_iif.hpp')
        assert_includes accessor.resource_bundles.fetch('boost_privacy'), pod_root.join('boost/PrivacyInfo.xcprivacy')
        source_installer.lock_files!([accessor])
        hooks.new.common_pre_install(installer)
      end
      assert_equal 1, downloads
      refute pod_root.join('boost').symlink?
      assert pod_root.join('boost/boost').symlink?
      assert_equal '// Homebrew header must remain unchanged and writable', brew_header.read
      assert_equal 0o644, brew_header.stat.mode & 0o777
    end
  end

  def test_post_install_preserves_files_indexed_by_cocoapods
    Dir.mktmpdir('boost-post-install-') do |root|
      sandbox = Pod::Sandbox.new(File.join(root, 'Pods'))
      pod_root = sandbox.root.join('boost')
      headers = pod_root.join('boost')
      header = headers.join('bind/bind_cc.hpp')
      privacy = headers.join('PrivacyInfo.xcprivacy')
      FileUtils.mkdir_p(header.dirname)
      header.write('// Header from the pinned pod source')
      privacy.write('<plist/>')

      # The podspec prepare command links Homebrew headers into a nested path.
      # A newer Homebrew installation need not contain every pinned pod header.
      brew_prefix = File.join(root, 'homebrew-boost')
      brew_headers = File.join(brew_prefix, 'include/boost')
      FileUtils.mkdir_p(brew_headers)
      File.write(File.join(brew_headers, 'version.hpp'), '// Homebrew header')
      File.symlink(brew_headers, headers.join('boost'))

      spec = Pod::Specification.new do |s|
        s.name = 'boost'
        s.version = '1.84.0'
        s.source_files = 'boost/**/*.{hpp,cpp}'
        s.header_mappings_dir = 'boost/boost'
        s.resource_bundles = { 'boost_privacy' => 'boost/PrivacyInfo.xcprivacy' }
      end
      accessor = Pod::Sandbox::FileAccessor.new(pod_root, spec.consumer(:ios))
      # CocoaPods indexes these before running the Podfile's post_install hook.
      assert_includes accessor.source_files, header
      assert_includes accessor.resource_bundles.fetch('boost_privacy'), privacy

      hooks = Class.new do
        def use_native_modules!
          { reactNativePath: 'unused' }
        end

        def react_native_post_install(*); end
      end
      common = File.read(File.join(SAMPLE_ROOT, 'ios/Podfile.common.rb'))
      hooks.class_eval(common.lines.reject { |line| line.start_with?('require ') }.join)
      hooks.define_method('`') { |_command| brew_prefix }
      hooks.define_method(:add_react_core_header_paths) { |_installer| }
      hooks.define_method(:add_pods_target_dependency) { |_installer| }
      installer = Struct.new(:sandbox, :pods_project).new(sandbox, Struct.new(:targets).new([]))
      hooks.new.common_post_install(installer)

      # Exercise the exact CocoaPods operation from the failing CI stack trace.
      source_installer = Pod::Installer::PodSourceInstaller.new(sandbox, Pod::Podfile.new, { ios: [spec] })
      source_installer.lock_files!([accessor])
      assert header.file?
      assert privacy.file?
      refute headers.symlink?
      assert headers.join('boost').symlink?
    end
  end
end
