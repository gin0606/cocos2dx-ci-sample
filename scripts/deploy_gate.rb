# -*- coding: utf-8 -*-
require 'uri'
require 'json'
require 'faraday'
require 'faraday_middleware'

class DeployGate
  def self.upload name, file_path, token, release_note=''
    url = URI.parse("https://deploygate.com/api/users/#{name}/apps")
    connection = Faraday.new(url: "#{url.scheme}://#{url.host}", request: { timeout: 120 }) do |builder|
      builder.request :multipart
      builder.request :json
      builder.response :json, :content_type => /\bjson$/
      builder.use FaradayMiddleware::FollowRedirects
      builder.adapter :net_http
    end

    params = {
      file: Faraday::UploadIO.new(file_path, 'application/octet-stream'),
      token: token,
    }
    # deploygateAPIはmessageにRelease Notesを入れるようになってる
    params [:message] = release_note unless release_note.empty?
    params [:release_note] = release_note unless release_note.empty?

    response = connection.post(url.path, params)
    case response.status
    when 200...300
      abort "DeployGate Error: #{response.body['message']}" if response.body['error']
      p 'Upload successfully uploaded to DeployGate'
    else
      abort "Error uploading to DeployGate: #{response.body}"
    end
  end
end
