# Phase 3 project wiring, run once via `ruby scripts/wire_floradexkit.rb`.
# Batched pbxproj mutations per the rewrite spec's Xcode-session protocol:
#   1. add the FloradexKit local package and link its product to the app target
#   2. remove the unused lottie-ios remote package
#   3. raise IPHONEOS_DEPLOYMENT_TARGET to 26.0 everywhere it is set
#   4. enable strict-concurrency warnings on the app target (SWIFT_VERSION stays 5)
# The resulting diff is reviewed and build-verified before anything else lands.

require 'xcodeproj'

project_path = File.expand_path('../plantlife.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

app_target = project.targets.find { |t| t.name == 'plantlife' }
raise 'app target not found' unless app_target

# 1. FloradexKit local package + product dependency + frameworks build file.
unless project.root_object.package_references.any? { |ref| ref.display_name.include?('FloradexKit') }
  local_ref = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
  local_ref.relative_path = 'FloradexKit'
  project.root_object.package_references << local_ref

  product_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  product_dep.product_name = 'FloradexKit'
  app_target.package_product_dependencies << product_dep

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = product_dep
  app_target.frameworks_build_phase.files << build_file
  puts 'added FloradexKit local package reference and linked the product'
end

# 2. Remove lottie-ios (dead since LottieView was deleted in phase 2).
project.targets.each do |target|
  dead_files = target.frameworks_build_phase.files.select do |bf|
    bf.product_ref && bf.product_ref.product_name == 'Lottie'
  end
  dead_files.each(&:remove_from_project)

  dead_deps = target.package_product_dependencies.select { |d| d.product_name == 'Lottie' }
  dead_deps.each do |dep|
    target.package_product_dependencies.delete(dep)
    dep.remove_from_project
  end
end
lottie_refs = project.root_object.package_references.select do |ref|
  ref.respond_to?(:repositoryURL) && ref.repositoryURL.to_s =~ /lottie/i
end
lottie_refs.each do |ref|
  project.root_object.package_references.delete(ref)
  ref.remove_from_project
  puts 'removed lottie-ios package reference'
end

# 3. Deployment target 26.0 wherever the key is currently defined.
(project.build_configurations + project.targets.flat_map(&:build_configurations)).each do |config|
  if config.build_settings.key?('IPHONEOS_DEPLOYMENT_TARGET')
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '26.0'
  end
end
puts 'deployment target set to 26.0'

# 4. Strict-concurrency warnings on the app target only.
app_target.build_configurations.each do |config|
  config.build_settings['SWIFT_STRICT_CONCURRENCY'] = 'complete'
end
puts 'strict concurrency (complete) enabled on plantlife target'

project.save
puts "saved #{project_path}"
