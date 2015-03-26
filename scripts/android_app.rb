require 'nokogiri'
require 'facter'
require './scripts/task_helper'

module Ant
  class Options
    attr_accessor :sdk_dir
    attr_accessor :keyStore
    def initialize sdk_dir
      @sdk_dir = sdk_dir
    end
    def unfold_options
      ret = ""
      ret << "-Dsdk.dir='#{@sdk_dir}'"
      ret << " #{@keyStore.unfold_options}" if @keyStore
      ret
    end
  end
  class KeyStore
    attr_accessor :path, :password
    attr_accessor :alias_name, :alias_password

    def initialize
      yield self if block_given?
    end

    def unfold_options
      ret = ""
      ret << "-Dkey.store='#{@path}'" if @path
      ret << " -Dkey.store.password='#{@password}'" if @password
      ret << " -Dkey.alias='#{@alias_name}'" if @alias_name
      ret << " -Dkey.alias.password='#{@alias_password}'" if @alias_password
      ret
    end
  end
end

module Android
  class Package
    attr_accessor :name
    attr_accessor :version_name
    attr_accessor :version_code
  end
end

class AndroidApp
  include TaskHelper

  def initialize project_root, build_configuration
    @project_root = project_root
    @build_configuration = build_configuration
    @androidManifest = Nokogiri::XML(open("#{@project_root}/AndroidManifest.xml"))
  end

  def set_xml_value value_path, attribute_name, value
    @androidManifest.xpath(value_path).first.attributes[attribute_name].value = value
    File.open("#{@project_root}/AndroidManifest.xml",'w') {|f| @androidManifest.write_xml_to f}
  end

  def get_xml_value value_path, attribute_name
    @androidManifest.xpath(value_path).first.attributes[attribute_name].value
  end

  def manifest_package
    get_xml_value '//manifest', 'package'
  end

  def manifest_package= package
    set_xml_value '//manifest', 'package', package
  end

  def version_name
    get_xml_value '//manifest', 'versionName'
  end

  def version_name= name
    set_xml_value '//manifest', 'versionName', name
  end

  def version_code
    get_xml_value '//manifest', 'versionCode'
  end

  def version_code= code
    set_xml_value '//manifest', 'versionCode', code.to_s
  end

  def app_name
    get_xml_value '/manifest/application', 'label'
  end

  def app_name= app_name
    set_xml_value '/manifest/application', 'label', app_name
    set_xml_value '/manifest/application/activity', 'label', app_name
  end

  def package
    ret = Android::Package.new
    ret.name = self.manifest_package
    ret.version_name = self.version_name
    ret.version_code = self.version_code
    ret
  end

  def package= package
    self.manifest_package = package.name
    self.version_name = package.version_name
    self.version_code = package.version_code
  end

  def clean sdk_dir
    sh "ant clean -buildfile '#{@project_root}/build.xml' -Dsdk.dir=#{sdk_dir}"
  end

  def build_apk ant_options, ndk_build_param: nil, clean: true, define_macros: {}, package: nil, app_name: nil
    clean ant_options.sdk_dir if clean

    file_backups = {
      "#{@project_root}/AndroidManifest.xml" => open("#{@project_root}/AndroidManifest.xml").read
    }
    begin
      if package and self.package.name != package.name
        Dir["#{@project_root}/src/**/*.java"].each do |path|
          file_backups[path] = open(path).read
          # アプリのpackageが変わるので、R.javaとかへの参照を直さないとビルド出来ない
          java_file = open(path, 'w')
          java_file.write(file_backups[path].gsub(/^import #{self.package.name}.R;/, "import #{package.name}.R;"))
          java_file.close()
        end
      end
      self.package = package if package
      self.app_name = app_name if app_name

      sh "ndk-build -j#{Facter.value(:processorcount)} -C #{@project_root} #{expand_ndk_build_param ndk_build_param, define_macros}"
      sh "ant release -buildfile '#{@project_root}/build.xml' #{ant_options.unfold_options}"
      apk_path
    ensure
      file_backups.each do |path, data|
        open(path, 'w') {|f| f.write data}
      end
    end
  end

  def zip_obj
    sh "cd '#{@project_root}' && zip -r obj.zip obj"
  end

  def expand_ndk_build_param ndk_build_param, define_macros
    result = ndk_build_param || ''
    return result if define_macros.empty?

    result += ' DEFINE_MACROS="' + define_macros.map {|k,v| "-D#{k}=#{v}"}.join(' ') + '"'
    raise "'//' は渡せない!" if result.match /\/\//
    result
  end

  def run package, activity_path: "org.cocos2dx.cpp.AppActivity", ant_options: nil, ndk_build_param: nil
    raise 'apkある状態で呼んでください' unless File.exists?(apk_path)
    install
    sh "adb shell am start -n #{package}/#{activity_path}"
  end

  def install
    # adb install は Failure になっても正常終了してしまうので、出力を見て判断する。
    sh "adb install -r '#{apk_path}' | ruby -pe 'success = false if $_.match /Failure/' -e 'BEGIN{success = true}' -e 'END{exit success}'"
  end

  def uninstall package
    sh "adb uninstall #{package}"
  end

  def project_name
    build_xml = Nokogiri::XML(open("#{@project_root}/build.xml"))
    build_xml.xpath('//project').first.attributes['name'].value
  end

  def apk_path
    "#{@project_root}/bin/#{project_name}-#{@build_configuration.downcase}.apk"
  end
end
