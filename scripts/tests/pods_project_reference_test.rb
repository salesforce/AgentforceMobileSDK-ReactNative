# frozen_string_literal: true

require 'minitest/autorun'
require 'cocoapods'
require 'xcodeproj'
require 'tmpdir'
require 'fileutils'
require 'open3'

class PodsProjectReferenceTest < Minitest::Test
  IOS_ROOT = File.expand_path('../../ios', __dir__)

  def setup
    @root = Dir.mktmpdir('rn-pods-project-')
    output, status = Open3.capture2e('xcodegen', 'generate', '--spec', File.join(IOS_ROOT, 'project.yml'), '--project', @root)
    assert status.success?, output
    @project = Xcodeproj::Project.open(File.join(@root, 'ReactAgentforce.xcodeproj'))
    @pods = Xcodeproj::Project.new(File.join(@root, 'Pods/Pods.xcodeproj'))
    @pods.new_target(:framework, 'FixtureDependency', :ios, '18.0')
    @pod_targets = %w[ServiceAgent EmployeeAgent].map { |name| @pods.new_aggregate_target("Pods-#{name}") }
    @pods.save
    aggregates = %w[ServiceAgent EmployeeAgent].map { |name|
      Struct.new(:name, :user_project).new("Pods-#{name}", @project)
    }
    @installer = Struct.new(:aggregate_targets, :pods_project).new(aggregates, @pods)
    @original_root = Pod::Config.instance.installation_root
    Pod::Config.instance.installation_root = Pathname.new(@root)
    hooks = Class.new
    common = File.join(IOS_ROOT, 'Podfile.common.rb')
    hooks.class_eval(File.read(common).lines.reject { |line| line.start_with?('require ') }.join, common)
    @hooks = hooks.new
  end

  def teardown
    Pod::Config.instance.installation_root = @original_root if @original_root
    FileUtils.rm_rf(@root) if @root
  end

  def assert_valid_reference
    @project = Xcodeproj::Project.open(@project.path)
    references = @project.root_object.project_references
    assert_equal 1, references.length
    reference = references.first
    products = reference[:product_group]
    refute_equal @project.products_group, products,
      'Pods must not share the app Products group: Xcode sends realReference to its children while saving'
    assert_equal ['FixtureDependency.framework'], products.children.map(&:path)
    products.children.each do |product|
      assert_equal 'PBXReferenceProxy', product.isa
      assert_equal reference[:project_ref].uuid, product.remote_ref.container_portal
      assert_equal @pods.targets.find { |target| target.name == 'FixtureDependency' }.product_reference.uuid,
        product.remote_ref.remote_global_id_string
    end
    assert @project.products_group.children.all? { |product| product.isa == 'PBXFileReference' }
    %w[ServiceAgent EmployeeAgent].each do |name|
      target = @project.targets.find { |item| item.name == name }
      assert_equal 1, target.dependencies.length
      proxy = target.dependencies.first.target_proxy
      assert_equal "Pods-#{name}", proxy.remote_info
      assert_equal @pods.targets.find { |item| item.name == "Pods-#{name}" }.uuid, proxy.remote_global_id_string
    end
  end

  def test_regenerated_project_keeps_app_and_pods_products_separate
    @hooks.add_pods_target_dependency(@installer)
    assert_valid_reference
  end

  def test_existing_dependencies_are_repaired_without_losing_signing_settings
    # Reproduce xcodeproj's legacy new_file behavior and already-added dependencies.
    @project.new_file(@pods.path)
    assert_equal @project.products_group, @project.root_object.project_references.first[:product_group]
    %w[ServiceAgent EmployeeAgent].zip(@pod_targets).each do |name, pod_target|
      target = @project.targets.find { |item| item.name == name }
      target.add_dependency(pod_target)
      target.build_configurations.each { |config|
        config.build_settings['DEVELOPMENT_TEAM'] = 'LOCALTEAM'
        config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
      }
    end
    @project.save
    @hooks.add_pods_target_dependency(@installer)
    assert_valid_reference
    @project.targets.select { |target| %w[ServiceAgent EmployeeAgent].include?(target.name) }.each do |target|
      target.build_configurations.each { |config|
        assert_equal 'LOCALTEAM', config.build_settings['DEVELOPMENT_TEAM']
        assert_equal 'Automatic', config.build_settings['CODE_SIGN_STYLE']
      }
    end
    before = File.binread(@project.path.join('project.pbxproj'))
    @hooks.add_pods_target_dependency(@installer)
    assert_equal before, File.binread(@project.path.join('project.pbxproj'))
  end
end
