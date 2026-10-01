#!/usr/bin/env ruby
# Adds the app_limiter iOS extensions to a Flutter app's Xcode project.
#
#   ruby add_ios_extensions.rb <path/to/Runner.xcodeproj> <group.your.app.group>
#
# Usually run through `dart run app_limiter:setup_ios`. Safe to run again: it
# refreshes the template files and keeps existing targets.
#
# It creates two extension targets from ios/extension_templates, embeds them
# in Runner, gives every target the Family Controls and App Group
# entitlements, and sets the AppLimiterAppGroup Info.plist key everywhere.
# Needs the `xcodeproj` gem, which comes with CocoaPods.

require 'fileutils'
require 'xcodeproj'

project_path, app_group = ARGV
abort "Usage: #{$PROGRAM_NAME} <Runner.xcodeproj> <group.your.app.group>" unless project_path && app_group
abort "App Group must start with 'group.': #{app_group}" unless app_group.start_with?('group.')

TEMPLATES = File.expand_path('../ios/extension_templates', __dir__)
SHARED_FILE = 'AppLimiterShared.swift'
DEPLOYMENT_TARGET = '16.0'
FAMILY_CONTROLS = 'com.apple.developer.family-controls'
APP_GROUPS = 'com.apple.security.application-groups'
APP_GROUP_KEY = 'AppLimiterAppGroup'

EXTENSIONS = [
  {
    name: 'AppLimiterShield',
    template: 'ShieldConfiguration',
    source: 'ShieldConfigurationExtension.swift',
    principal_class: 'ShieldConfigurationExtension',
    extension_point: 'com.apple.ManagedSettingsUI.shield-configuration-service',
    display_name: 'Shield',
  },
  {
    name: 'AppLimiterMonitor',
    template: 'DeviceActivityMonitor',
    source: 'DeviceActivityMonitorExtension.swift',
    principal_class: 'DeviceActivityMonitorExtension',
    extension_point: 'com.apple.deviceactivity.monitor-extension',
    display_name: 'Activity Monitor',
  },
].freeze

project = Xcodeproj::Project.open(project_path)
ios_dir = File.dirname(File.expand_path(project_path))
runner = project.targets.find { |t| t.name == 'Runner' } or abort 'Runner target not found'

def update_entitlements(path, app_group)
  entitlements = File.exist?(path) ? Xcodeproj::Plist.read_from_path(path) : {}
  entitlements[FAMILY_CONTROLS] = true
  groups = Array(entitlements[APP_GROUPS])
  entitlements[APP_GROUPS] = (groups + [app_group]).uniq
  Xcodeproj::Plist.write_to_path(entitlements, path)
end

def extension_info_plist(extension, app_group)
  {
    'CFBundleDevelopmentRegion' => '$(DEVELOPMENT_LANGUAGE)',
    'CFBundleDisplayName' => extension[:display_name],
    'CFBundleExecutable' => '$(EXECUTABLE_NAME)',
    'CFBundleIdentifier' => '$(PRODUCT_BUNDLE_IDENTIFIER)',
    'CFBundleInfoDictionaryVersion' => '6.0',
    'CFBundleName' => '$(PRODUCT_NAME)',
    'CFBundlePackageType' => '$(PRODUCT_BUNDLE_PACKAGE_TYPE)',
    'CFBundleShortVersionString' => '$(MARKETING_VERSION)',
    'CFBundleVersion' => '$(CURRENT_PROJECT_VERSION)',
    APP_GROUP_KEY => app_group,
    'NSExtension' => {
      'NSExtensionPointIdentifier' => extension[:extension_point],
      'NSExtensionPrincipalClass' => "$(PRODUCT_MODULE_NAME).#{extension[:principal_class]}",
    },
  }
end

# Runner: entitlements and Info.plist key.
runner.build_configurations.each do |config|
  relative = config.build_settings['CODE_SIGN_ENTITLEMENTS']
  if relative.nil? || relative.empty?
    relative = 'Runner/Runner.entitlements'
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = relative
    runner_group = project.main_group.find_subpath('Runner', false)
    if runner_group && runner_group.files.none? { |f| f.path == 'Runner.entitlements' }
      runner_group.new_reference('Runner.entitlements')
    end
  end
  update_entitlements(File.join(ios_dir, relative), app_group)
end

runner_info_path = File.join(ios_dir, runner.build_configurations.first.build_settings['INFOPLIST_FILE'] || 'Runner/Info.plist')
runner_info = Xcodeproj::Plist.read_from_path(runner_info_path)
runner_info[APP_GROUP_KEY] = app_group
# Entitlements belong in the .entitlements file, not in Info.plist.
runner_info.delete(FAMILY_CONTROLS)
runner_info.delete('com.apple.developer.device-activity-monitoring')
Xcodeproj::Plist.write_to_path(runner_info, runner_info_path)

# Embed phase, kept before the Flutter script phases to avoid build cycles.
embed_phase = runner.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' }
unless embed_phase
  embed_phase = runner.new_copy_files_build_phase('Embed Foundation Extensions')
  embed_phase.symbol_dst_subfolder_spec = :plug_ins
end
runner.build_phases.delete(embed_phase)
resources_index = runner.build_phases.index(runner.resources_build_phase) || (runner.build_phases.size - 1)
runner.build_phases.insert(resources_index + 1, embed_phase)

EXTENSIONS.each do |extension|
  name = extension[:name]
  dir = File.join(ios_dir, name)
  FileUtils.mkdir_p(dir)
  FileUtils.cp(File.join(TEMPLATES, extension[:template], extension[:source]), dir)
  FileUtils.cp(File.join(TEMPLATES, SHARED_FILE), dir)
  Xcodeproj::Plist.write_to_path(extension_info_plist(extension, app_group), File.join(dir, 'Info.plist'))
  update_entitlements(File.join(dir, "#{name}.entitlements"), app_group)

  target = project.targets.find { |t| t.name == name }
  created = target.nil?
  if created
    target = project.new_target(:app_extension, name, :ios, DEPLOYMENT_TARGET, nil, :swift)
    group = project.main_group.new_group(name, name)
    sources = [extension[:source], SHARED_FILE].map { |file| group.new_reference(file) }
    target.add_file_references(sources)
    group.new_reference('Info.plist')
    group.new_reference("#{name}.entitlements")
  end
  unless target.build_configurations.any? { |c| c.name == 'Profile' }
    target.add_build_configuration('Profile', :release)
  end

  target.build_configurations.each do |config|
    runner_config = runner.build_configurations.find { |c| c.name == config.name } ||
                    runner.build_configurations.find { |c| c.name == 'Release' }
    runner_settings = runner_config.build_settings
    settings = config.build_settings
    settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
    settings['PRODUCT_BUNDLE_IDENTIFIER'] = "#{runner_settings['PRODUCT_BUNDLE_IDENTIFIER']}.#{name}"
    settings['DEVELOPMENT_TEAM'] = runner_settings['DEVELOPMENT_TEAM'] if runner_settings['DEVELOPMENT_TEAM']
    settings['CODE_SIGN_STYLE'] = 'Automatic'
    settings['INFOPLIST_FILE'] = "#{name}/Info.plist"
    settings['GENERATE_INFOPLIST_FILE'] = 'NO'
    settings['CODE_SIGN_ENTITLEMENTS'] = "#{name}/#{name}.entitlements"
    settings['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
    settings['SWIFT_VERSION'] = '5.0'
    settings['TARGETED_DEVICE_FAMILY'] = '1,2'
    settings['MARKETING_VERSION'] = '1.0'
    settings['CURRENT_PROJECT_VERSION'] = '1'
    settings['SKIP_INSTALL'] = 'YES'
    settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  end

  runner.add_dependency(target) unless runner.dependencies.any? { |d| d.target == target }
  unless embed_phase.files_references.include?(target.product_reference)
    build_file = embed_phase.add_file_reference(target.product_reference, true)
    build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  end
  puts "#{created ? 'Added' : 'Updated'} #{name}"
end

project.save
puts "Done. App Group: #{app_group}"
puts 'Open the project in Xcode once to let automatic signing register the App Group and extension IDs.'
