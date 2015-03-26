# -*- coding: utf-8 -*-
require './scripts/environment'
require './scripts/xcode_app'
require './scripts/android_app'
require './scripts/deploy_gate'

APP_NAME = 'SampleProject'
GITHUB_REPOSITORY_NAME = 'gin0606/cocos2dx-ci-sample'
BUILD_CONFIGURATION = 'Debug'
BUILD_CONFIGURATION_ANDROID = 'Release'
CODE_SIGN_IDENTITY = 'iPhone Distribution'

ANDROID_APP_PACKAGE = "your.package"
DEPLOYGATE_GROUP_NAME = 'your_deploygate_group'

REPOSITORY_ROOT = Dir.pwd
IOS_PROJECT_PATH = "#{REPOSITORY_ROOT}/#{APP_NAME}/proj.ios_mac/#{APP_NAME}.xcodeproj"
ANDROID_PROJECT_ROOT = "#{REPOSITORY_ROOT}/#{APP_NAME}/proj.android"

ANDROID_APP = AndroidApp.new ANDROID_PROJECT_ROOT, BUILD_CONFIGURATION_ANDROID
XCODE_APP = XcodeApp.new IOS_PROJECT_PATH, "#{APP_NAME} iOS"

LOCAL_PROVISIONING_PROFILES_PATH = "#{REPOSITORY_ROOT}/Provisioning_Profile"
APP_DST_PATH = "#{REPOSITORY_ROOT}/tmp/ios_build_dst"


desc "Run unit test"
task :utest do
  sh "#{REPOSITORY_ROOT}/scripts/ios-sim start --devicetypeid 'com.apple.CoreSimulator.SimDeviceType.iPhone-6, 8.1' &"

  destination = 'name=iPhone 6,OS=8.1'
  XCODE_APP.unit_test destination, APP_DST_PATH
end

namespace :ios do
  desc "Clean build files"
  task :clean do
    XCODE_APP.clean APP_DST_PATH
  end

  namespace :clean do
    desc "Clean build alltargets files"
    task :all do
      XCODE_APP.clean APP_DST_PATH, alltargets: true
    end
  end

  desc "Build ipa file"
  task :build do
    XCODE_APP.build_ipa BUILD_CONFIGURATION, CODE_SIGN_IDENTITY, APP_DST_PATH, adhoc_provisioning_path
  end

  desc "Build and run for iOS"
  task :run do
    app_path = XCODE_APP.build_app APP_DST_PATH
    sh "#{REPOSITORY_ROOT}/scripts/ios-sim launch '#{app_path}' &"
  end

  namespace :adhoc do
    desc "Upload ios app for "
    task :all do
      Environment.has_variables 'DEPLOYGATE_TOKEN'
      ipa_path = XCODE_APP.build_ipa BUILD_CONFIGURATION, CODE_SIGN_IDENTITY, APP_DST_PATH, adhoc_provisioning_path
      DeployGate.upload DEPLOYGATE_GROUP_NAME, ipa_path, ENV['DEPLOYGATE_TOKEN'], fetch_recently_merged_pull_request_title
    end

    desc "Upload ios app for developer"
    task :dev do
      bundle_name_backup = XCODE_APP.plist_get 'CFBundleName'
      bundle_display_name_backup = XCODE_APP.plist_get 'CFBundleDisplayName'
      bundle_identifier_backup = XCODE_APP.plist_get 'CFBundleIdentifier'
      XCODE_APP.plist_set 'CFBundleName', "#{dev_app_name}"
      XCODE_APP.plist_set 'CFBundleDisplayName', "dev_#{bundle_display_name_backup}"
      XCODE_APP.plist_set 'CFBundleIdentifier', "#{bundle_identifier_backup + '.dev'}"
      begin
        Environment.has_variables 'DEPLOYGATE_TOKEN'
        ipa_path = XCODE_APP.build_ipa BUILD_CONFIGURATION, CODE_SIGN_IDENTITY, APP_DST_PATH, adhoc_provisioning_path
        DeployGate.upload DEPLOYGATE_GROUP_NAME, ipa_path, ENV['DEPLOYGATE_TOKEN']
      ensure
        XCODE_APP.plist_set 'CFBundleName', bundle_name_backup
        XCODE_APP.plist_set 'CFBundleDisplayName', bundle_display_name_backup
        XCODE_APP.plist_set 'CFBundleIdentifier', bundle_identifier_backup
      end
    end
  end
end

namespace :android do
  ant_options = Ant::Options.new(ENV['ANDROID_HOME'])
  if ENV['KEY_STORE_PASSWORD'] and ENV['KEY_ALIAS_PASSWORD']
    ant_options.keyStore = Ant::KeyStore.new do |keyStore|
      keyStore.path = "#{REPOSITORY_ROOT}/certificates/dev.keystore"
      keyStore.password = ENV['KEY_STORE_PASSWORD']
      keyStore.alias_name = 'alias_name'
      keyStore.alias_password = ENV['KEY_ALIAS_PASSWORD']
    end
  end

  desc "Build apk file"
  task :build do
    Environment.has_variables 'ANDROID_HOME'

    build_spec = YAML.load_file("#{REPOSITORY_ROOT}/build_spec/pre_release.yaml")
    ANDROID_APP.build_apk ant_options, define_macros: {ENABLE_SANDBOX: build_spec['sandbox'], HTTP_API_ROOT: build_spec['api']['root']}
  end

  desc "Build apk file with sandbox"
  task :build_sandbox do
    Environment.has_variables 'ANDROID_HOME'

    build_spec = YAML.load_file("#{REPOSITORY_ROOT}/build_spec/development.yaml")
    ANDROID_APP.build_apk ant_options, ndk_build_param: 'NDK_DEBUG=1', define_macros: {ENABLE_SANDBOX: build_spec['sandbox']}
  end

  desc "Clean build files"
  task :clean do
    Environment.has_variables 'ANDROID_HOME'
    ANDROID_APP.clean ENV['ANDROID_HOME']
  end

  desc "Build and run for android"
  task :run do
    Environment.has_variables 'ANDROID_HOME'
    ANDROID_APP.build_apk ant_options, ndk_build_param: 'APP_ABI=x86,armeabi NDK_DEBUG=1', clean: false, define_macros: {ENABLE_SANDBOX: 1}
    ANDROID_APP.run ANDROID_APP_PACKAGE
  end

  desc "Uninstall apk"
  task :uninstall do
    ANDROID_APP.uninstall ANDROID_APP_PACKAGE
  end

  namespace :adhoc do
    task :deploygate_upload do
      Environment.has_variables 'DEPLOYGATE_TOKEN'
      DeployGate.upload DEPLOYGATE_GROUP_NAME, ANDROID_APP.apk_path, ENV['DEPLOYGATE_TOKEN'], fetch_recently_merged_pull_request_title
    end

    desc "Upload ios app for all"
    task :all => ["android:build_sandbox", "android:adhoc:deploygate_upload"]
  end
end

def dev_app_name
  "#{`git rev-parse --short HEAD`.chomp}-#{`git rev-parse --abbrev-ref HEAD`.chomp}"
end

def adhoc_provisioning_path
  "#{LOCAL_PROVISIONING_PROFILES_PATH}/adhoc.mobileprovision"
end

def fetch_recently_merged_pull_request_title
  return '' unless ENV['GITHUB_ACCESS_TOKEN']
  require 'octokit'
  client = Octokit::Client.new(access_token: ENV['GITHUB_ACCESS_TOKEN'])
  pull_requests = client.pull_requests(GITHUB_REPOSITORY_NAME, {
      state: 'closed',
      direction: 'desc',
      sort: 'updated'
    })
  pull_requests[0][:title]
end

Dir["#{REPOSITORY_ROOT}/scripts/tasks/**/*.rake"].each do |path|
  load path
end
