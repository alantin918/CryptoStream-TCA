require 'xcodeproj'

# 從本機的 .teamid 檔案讀取 Team ID（此檔案不會提交到 git）
# 如果沒有此檔案，Xcode 每次都要手動選擇 Team
team_id = ''
team_id_file = '.teamid'
if File.exist?(team_id_file)
  team_id = File.read(team_id_file).strip
  puts "Using Team ID: #{team_id}"
else
  puts "Tip: Create a .teamid file with your Apple Team ID to avoid re-selecting team each time."
  puts "     Example: echo 'AB12CD34EF' > .teamid"
end

project = Xcodeproj::Project.new('CryptoApp.xcodeproj')
target = project.new_target(:application, 'CryptoApp', :ios, '16.0')

project.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '5.0'
end

target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_KEY_UIApplicationSceneManifest_Generation'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UIRequiresFullScreen'] = 'YES'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.gemini.CryptoApp'
  config.build_settings['DEVELOPMENT_TEAM'] = team_id
end

main_group = project.main_group
app_file = main_group.new_file('CryptoApp.swift')
target.add_file_references([app_file])

def add_files_recurse(group, dir, target)
  Dir.glob(File.join(dir, '*')).each do |path|
    basename = File.basename(path)
    if File.directory?(path)
      subgroup = group.new_group(basename, basename)
      add_files_recurse(subgroup, path, target)
    elsif path.end_with?('.swift')
      ref = group.new_file(basename)
      target.add_file_references([ref])
    end
  end
end

sources_group = main_group.new_group('Sources', 'Sources')
add_files_recurse(sources_group, 'Sources', target)

# Tests folder (we just add it to navigator so they can see tests, not building them in the app target)
tests_group = main_group.new_group('Tests', 'Tests')
def add_tests_recurse(group, dir)
  Dir.glob(File.join(dir, '*')).each do |path|
    basename = File.basename(path)
    if File.directory?(path)
      subgroup = group.new_group(basename, basename)
      add_tests_recurse(subgroup, path)
    elsif path.end_with?('.swift')
      group.new_file(basename)
    end
  end
end
add_tests_recurse(tests_group, 'Tests')

# Add Assets.xcassets
assets_ref = main_group.new_file('Assets.xcassets')
target.resources_build_phase.add_file_reference(assets_ref)

target.build_configurations.each do |config|
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
end

# TCA Swift Package
pkg_ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
pkg_ref.repositoryURL = 'https://github.com/pointfreeco/swift-composable-architecture.git'
pkg_ref.requirement = { 'kind' => 'exactVersion', 'version' => '1.0.0' }
project.root_object.package_references << pkg_ref

product_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
product_dep.product_name = 'ComposableArchitecture'
product_dep.package = pkg_ref
target.package_product_dependencies << product_dep

build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
build_file.product_ref = product_dep
target.frameworks_build_phase.files << build_file

project.save
puts 'Xcode Project Successfully Generated!'
