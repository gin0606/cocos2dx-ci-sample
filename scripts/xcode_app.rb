require 'xcodeproj'
require './scripts/task_helper'

class XcodeApp
  include TaskHelper

  def initialize project_path, target_name
    @project_path = project_path
    @project_root = File::dirname project_path
    xcode_project = Xcodeproj::Project.open(project_path)
    @scheme = xcode_project.targets.find{|elem| elem.name == target_name}
    @configurations = xcode_project.build_configuration_list.build_configurations.map {|config| config.name}
  end

  def clean dest_path, alltargets: false
    options = {
      project: @project_path,
      scheme: @scheme.name,
    }
    settings = {
      CONFIGURATION_TEMP_DIR: "#{dest_path}/tmp",
      CONFIGURATION_BUILD_DIR: dest_path,
    }
    @configurations.each do |configration|
      build options.merge({configuration: configration}), settings, [:clean]
    end

    if alltargets
      build options, settings, [:clean], alltargets: true
    end
  end

  def unit_test destination, dest_path, define_macros: {}
    options = {
      project: @project_path,
      scheme: @scheme.name,
      destination: destination,
    }
    settings = {
      CONFIGURATION_TEMP_DIR: "#{dest_path}/tmp",
      CONFIGURATION_BUILD_DIR: dest_path,
    }
    build options, settings, [:test], define_macros: define_macros
  end

  def build_ipa build_configuration, code_sign_identity, dest_path, provisioning_path, define_macros: {}
    FileUtils.remove_dir(dest_path) if File.exists?(dest_path)

    build_options = {
      project: @project_path,
      scheme: @scheme.name,
      sdk: @scheme.sdk,
      configuration: build_configuration,
    }
    build_settings = {
      CODE_SIGN_IDENTITY: code_sign_identity,
      CONFIGURATION_TEMP_DIR: "#{dest_path}/tmp",
      CONFIGURATION_BUILD_DIR: dest_path,
    }
    xcrun_options = {
      sdk: @scheme.sdk,
    }
    ipa_path = "#{dest_path}/#{screen_name.gsub(/\.\w*$/i, '')}.ipa"
    xcrun_tool_options = {
      o: ipa_path,
      embed: provisioning_path
    }
    build build_options, build_settings, [:clean, :build], define_macros: define_macros, provisioning_path: provisioning_path
    sh "xcrun #{unfold_options(xcrun_options)} PackageApplication '#{dest_path}/#{screen_name}' #{unfold_options(xcrun_tool_options)}"
    sh "cd '#{dest_path}' && zip -r '#{screen_name}.dSYM.zip' '#{screen_name}.dSYM'"
    ipa_path
  end

  def build_app dest_path, define_macros: {}
    options = {
      project: @project_path,
      scheme: @scheme.name,
      sdk: 'iphonesimulator',
      configuration: 'Debug',
      arch: 'i386',
    }
    settings = {
      CONFIGURATION_TEMP_DIR: "#{dest_path}/tmp",
      CONFIGURATION_BUILD_DIR: dest_path,
    }
    build options, settings, nil, define_macros: define_macros
    "#{dest_path}/#{screen_name}"
  end

  def build build_options, build_settings, build_actions, alltargets: false, define_macros: {}, provisioning_path: ''
    build_options.delete :scheme if alltargets # alltargetsの時はsceme指定できない

    unless define_macros.empty?
      build_settings ||= {}
      build_settings['GCC_PREPROCESSOR_DEFINITIONS'] = '$(inherited) ' + define_macros.map {|k,v| "#{k}=#{v}"}.join(' ')
    end
    unless provisioning_path.empty?
      install_mobileprovision provisioning_path
      build_settings ||= {}
      build_settings['PROVISIONING_PROFILE'] = mobileprovision_uuid provisioning_path
    end

    option = unfold_options(build_options) unless build_options.nil?
    setting = unfold_options(build_settings, prefix='', seperator='=') unless build_settings.nil?
    actions = build_actions.join(" ") unless build_actions.nil?
    sh "xcodebuild #{'-alltargets' if alltargets} #{[option, setting, actions].compact.join ' '} #{'| xcpretty -c && exit ${PIPESTATUS[0]}' unless ENV['VERBOSE'] }"
  end

  def scheme
    @scheme
  end

  def screen_name
    @scheme.product_reference.display_name
  end

  def plist_set key, value
    sh "/usr/libexec/PlistBuddy -c 'Set :#{key} \"#{value}\"' '#{@project_root}/ios/Info.plist'"
  end

  def plist_get key
    `/usr/libexec/PlistBuddy -c "Print #{key}" '#{@project_root}/ios/Info.plist'`.chomp
  end

  def mobileprovision_uuid path
    binary = open(path).read
    key_index = binary.lines.index {|l| l.include? '<key>UUID</key>'}
    uuid_line = binary.lines[key_index + 1]
    match = uuid_line.match %r|<string>([\w-]+)</string>|
    uuid = match[1]
  end

  PROVISIONING_PROFILES_PATH = "#{Dir.home}/Library/MobileDevice/Provisioning Profiles"

  def install_mobileprovision path
    uuid = mobileprovision_uuid path
    installed_path = "#{PROVISIONING_PROFILES_PATH}/#{uuid}.mobileprovision"
    unless File.exists? installed_path
      puts "Install Provisioning Profiles #{path} (#{uuid})"
      sh "mkdir -p '#{PROVISIONING_PROFILES_PATH}'"
      sh "cp '#{path}' '#{installed_path}'"
    end
  end
end
