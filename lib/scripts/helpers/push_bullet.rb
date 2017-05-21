require 'net/http'
require 'uri'
require 'json'
require_relative 'secrets'

class PushBullet
  def self.send(title, body)
    uri = URI('https://api.pushbullet.com/v2/pushes')

    request = Net::HTTP::Post.new(
      uri.request_uri, 
      'Content-Type' => 'application/json',
      'Access-Token' => Secrets.secrets['pushbullet_token']
    )
    request.body = {
      body: body,
      title: title,
      type: 'note'
    }.to_json

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    resp = http.request(request)
    resp.code.to_i == 200
  end
end
