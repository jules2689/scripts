require "net/http"
require "uri"
require_relative 'helpers/sys_logger'
require_relative 'helpers/secrets'
require_relative 'wishlist/amazon'
require_relative 'wishlist/generic'
require_relative 'wishlist/shopify'
require 'airrecord'

class WishlistItem < Airrecord::Table
  self.api_key = Secrets.secrets["airtable_api_key"]
  self.base_key = Secrets.secrets["airtable_wishlist_app_id"]
  self.table_name = Secrets.secrets["airtable_wishlist_table_id"]
end

def is_shopify?(url)
  orig_uri = URI(url)
  uri = URI("#{orig_uri.scheme}://#{orig_uri.host}/meta.json")
  response = Net::HTTP.get_response(uri)
  JSON.parse(response.body).key?('myshopify_domain')
rescue
  false
end

SysLogger.logger.info "Starting wishlist sync with Airtable"
WishlistItem.all.each do |wishlist|
  next unless wishlist[:link] && wishlist[:title].nil?
  url = wishlist[:link]
  SysLogger.logger.info "Syncing item #{url}"

  scraped_data = if url.match(/amazon\.(ca|com)/)
    SysLogger.logger.info "#{url} is from Amazon"
    Wishlist::Amazon.scrape(url)
  elsif is_shopify?(url)
    SysLogger.logger.info "#{url} is from Shopify"
    Wishlist::Shopify.scrape(url)
  else
    SysLogger.logger.info "#{url} is from a generic store"
    Wishlist::Generic.scrape(url)
  end

  wishlist['Title'] = scraped_data[:title]
  wishlist['Price'] = scraped_data[:price].to_f
  wishlist['Notes'] = scraped_data[:desc]
  wishlist['Pictures'] = [{ url: scraped_data[:image] }]
  wishlist.save
end
SysLogger.logger.info 'Finished Sync'
