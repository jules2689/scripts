require 'json'
require "net/http"
require "uri"
require_relative 'secrets'
require_relative 'scrappy_store'

class PocketApi
  BASE_URL = "https://getpocket.com/v3/"

  def self.fetch_listings
    consumer_key = Secrets.secrets['pocket_consumer_key']
    access_token = Secrets.secrets['pocket_access_token']
    since_timestamp = ScrappyStore.read('pocket_since_timestamp', 1)

    uri = URI(BASE_URL + 'get')
    params = {
      consumer_key: consumer_key,
      access_token: access_token,
      state: 'all',
      sort: 'newest',
      detailType: 'complete',
      since: since_timestamp
    }
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)
    json_response = begin
      JSON.parse(response.body)
    rescue JSON::ParserError
      SysLogger.logger.info "Could not parse response from Pocket: #{response.body}"
      nil
    end

    ScrappyStore.write('pocket_since_timestamp', json_response['since'])
    json_response['list'].is_a?(Hash) ? json_response['list'].values : []
  end
end
