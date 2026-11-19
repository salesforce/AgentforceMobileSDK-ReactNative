# frozen_string_literal: true

require 'minitest/autorun'
require 'cocoapods'
require 'fileutils'
require 'open3'
require 'tmpdir'

class FmtCompatibilityTest < Minitest::Test
  SAMPLE_ROOT = File.expand_path('../..', __dir__)
  ORIGINAL_GUARD = '#elif defined(__apple_build_version__) && __apple_build_version__ < 14000029L'

  def setup
    @root = Dir.mktmpdir('fmt-compatibility-')
    @sandbox = Pod::Sandbox.new(File.join(@root, 'Pods'))
    @header = @sandbox.root.join('fmt/include/fmt/base.h')
    FileUtils.mkdir_p(@header.dirname)
    @header.write("#if 0\n#{ORIGINAL_GUARD}\n#define FMT_USE_CONSTEVAL 0\n#else\n#define FMT_USE_CONSTEVAL 1\n#endif\n")
    @spec = Pod::Specification.new { |s| s.name = 'fmt'; s.version = '11.0.2' }
    target = Struct.new(:name, :root_spec).new('fmt', @spec)
    @installer = Struct.new(:sandbox, :pod_targets).new(@sandbox, [target])
    hooks = Class.new
    common = File.read(File.join(SAMPLE_ROOT, 'ios/Podfile.common.rb'))
    hooks.class_eval(common.lines.reject { |line| line.start_with?('require ') }.join)
    @hooks = hooks.new
  end

  def teardown
    FileUtils.rm_rf(@root)
  end

  def test_pre_install_handles_read_only_cached_header_and_is_idempotent
    File.chmod(0o444, @header)
    @hooks.common_pre_install(@installer)
    content = @header.read
    assert_includes content, '__apple_build_version__ >= 21000000L'
    assert_equal 0o444, @header.stat.mode & 0o777
    modified_at = @header.mtime

    @hooks.common_pre_install(@installer)
    assert_equal content, @header.read
    assert_equal modified_at, @header.mtime
  end

  def test_newer_fmt_is_untouched
    @spec.version = '12.1.0'
    @header.write('Newer fmt implementation')
    @hooks.common_pre_install(@installer)
    assert_equal 'Newer fmt implementation', @header.read
  end

  def test_no_fmt_is_supported
    @installer.pod_targets.clear
    @header.delete
    @hooks.common_pre_install(@installer)
    refute_path_exists @header
  end

  def test_compiler_guard_preserves_older_apple_clang_behavior
    skip 'Compiler guard check requires Xcode tools' unless RUBY_PLATFORM.include?('darwin')

    @hooks.common_pre_install(@installer)
    { 13000000 => '0', 14000029 => '1', 20000000 => '1', 21000000 => '0', 22000000 => '0' }.each do |build, expected|
      output, errors, status = Open3.capture3('xcrun', 'clang++', '-E', '-P', '-x', 'c++',
        '-Wno-macro-redefined', "-D__apple_build_version__=#{build}", '-',
        stdin_data: "#include \"#{@header}\"\nFMT_USE_CONSTEVAL\n")
      assert status.success?, errors
      assert_equal expected, output.strip, "Apple Clang build #{build}"
    end
  end

  def test_changed_header_layout_fails_with_actionable_error
    @header.write('Unexpected fmt 11.0.2 implementation')
    error = assert_raises(Pod::Informative) { @hooks.common_pre_install(@installer) }
    assert_includes error.message, 'review the Apple Clang compatibility patch'
  end
end
