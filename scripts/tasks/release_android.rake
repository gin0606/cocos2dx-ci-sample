require 'yaml'

def slack_post_message token: "", text: "", channel: ""
  url = URI.parse("https://slack.com/api/chat.postMessage")
  connection = Faraday.new(url: "#{url.scheme}://#{url.host}", request: { timeout: 120 }) do |builder|
    builder.request  :url_encoded
    builder.request :json
    builder.response :json, :content_type => /\bjson$/
    builder.use FaradayMiddleware::FollowRedirects
    builder.adapter :net_http
  end

  params = {
    token: token,
    text: text,
    channel: channel,
    as_user: true,
    link_names: 1
  }

  response = connection.post url.path, params
end

def slack_upload path: "", token: "", title: "", channels: []
  url = URI.parse("https://slack.com/api/files.upload")
  connection = Faraday.new(url: "#{url.scheme}://#{url.host}", request: { timeout: 120 }) do |builder|
    builder.request :multipart
    builder.request :json
    builder.response :json, :content_type => /\bjson$/
    builder.use FaradayMiddleware::FollowRedirects
    builder.adapter :net_http
  end

  params = {
    file: Faraday::UploadIO.new(path, 'multipart/form-data'),
    token: token,
    title: title,
    channels: channels.map{|c| c[:id]}.join(','),
  }

  response = connection.post(url.path, params)
  case response.status
  when 200...300
    abort "Slack Error: #{response.body['message']}" if response.body['error']
    slack_post_message(
      token: token,
      text: "@channel: 上げたよー #{response.body['permalink']}",
      channel: channels[0][:name]
    )
  else
    abort "Error uploading to Slack: #{response.body}"
  end
end

namespace :release do
  namespace :android do
    desc 'Release build for jp'
    task :jp do
      Environment.has_variables 'ANDROID_HOME', 'KEY_STORE_PASSWORD', 'KEY_ALIAS_PASSWORD'

      ant_options = Ant::Options.new(ENV['ANDROID_HOME'])
      ant_options.keyStore = Ant::KeyStore.new do |keyStore|
        keyStore.path = "#{REPOSITORY_ROOT}/certificates/jp.keystore"
        keyStore.password = ENV['KEY_STORE_PASSWORD']
        keyStore.alias_name = 'alias_name'
        keyStore.alias_password = ENV['KEY_ALIAS_PASSWORD']
      end

      build_spec = YAML.load_file("#{REPOSITORY_ROOT}/build_spec/jp.yaml")

      macros = {ENABLE_SANDBOX: build_spec['sandbox'], HTTP_API_ROOT: build_spec['api']['root']}

      package = Android::Package.new
      package.name = build_spec['android']['package']
      package.version_name = build_spec['android']['version_name']
      package.version_code = build_spec['android']['version_code']

      apk_path = ANDROID_APP.build_apk ant_options, define_macros: macros, package: package
      ANDROID_APP.zip_obj
      p "#{apk_path} にapk生成されました"

      if !!ENV['SLACK_API_TOKEN']
        slack_upload(
          path: apk_path,
          token: ENV['SLACK_API_TOKEN'],
          title: "#{File.basename(apk_path)}#{build_spec['android']['version_name']}(#{build_spec['android']['version_code']})",
          channels: [{name: '#slack-room', id: "id"}] # fileのAPIはIDじゃないとpostできない
        )
      end
    end
    namespace :jp do
      desc 'Run release build for jp'
      task :run => ["release:android:jp"] do
        build_spec = YAML.load_file("#{REPOSITORY_ROOT}/build_spec/jp.yaml")
        ANDROID_APP.run build_spec['android']['package']
      end
    end
  end
end
