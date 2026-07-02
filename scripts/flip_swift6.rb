# Phase 6 language flip, run once via `ruby scripts/flip_swift6.rb`.
# Batched pbxproj mutation per the rewrite spec's Xcode-session protocol:
#   1. SWIFT_VERSION 5.0 -> 6.0 on every build configuration
#   2. SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor on the app target only
#      (XCTestCase's nonisolated lifecycle cannot be overridden under a
#      MainActor default; the test target isolates classes explicitly)
#   3. drop SWIFT_STRICT_CONCURRENCY, redundant under Swift 6
# The resulting diff is reviewed and build-verified before anything else lands.

require 'xcodeproj'

project_path = File.expand_path('../plantlife.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

isolated_targets = %w[plantlife]

project.build_configurations.each do |config|
  if config.build_settings['SWIFT_VERSION']
    config.build_settings['SWIFT_VERSION'] = '6.0'
    puts "project/#{config.name}: SWIFT_VERSION = 6.0"
  end
end

project.targets.each do |target|
  target.build_configurations.each do |config|
    if config.build_settings['SWIFT_VERSION']
      config.build_settings['SWIFT_VERSION'] = '6.0'
      puts "#{target.name}/#{config.name}: SWIFT_VERSION = 6.0"
    end
    if config.build_settings.delete('SWIFT_STRICT_CONCURRENCY')
      puts "#{target.name}/#{config.name}: dropped SWIFT_STRICT_CONCURRENCY"
    end
    if isolated_targets.include?(target.name)
      config.build_settings['SWIFT_DEFAULT_ACTOR_ISOLATION'] = 'MainActor'
      puts "#{target.name}/#{config.name}: SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor"
    end
  end
end

project.save
puts 'saved'
