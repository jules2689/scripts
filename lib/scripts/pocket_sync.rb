require 'net/http'
require 'uri'
require 'time'
require_relative 'helpers/sys_logger'
require_relative 'helpers/secrets'
require_relative 'helpers/pocket_api'
require 'airrecord'

class Article < Airrecord::Table
  self.api_key = Secrets.secrets['airtable_api_key']
  self.base_key = Secrets.secrets['airtable_pocket_app_id']
  self.table_name = Secrets.secrets['airtable_pocket_table_id']
end

SysLogger.logger.info "Starting Pocket sync with Airtable"

current_articles = Article.all
original_since_timestamp = ScrappyStore.read('pocket_since_timestamp', 1)
listings = PocketApi.fetch_listings.reject { |l| l['given_url'].nil? }

begin
  listings.each_with_index do |listing, idx|
    title = listing['resolved_title'].nil? || listing['resolved_title'] == '' ? title : listing['resolved_title']

    if article = current_articles.detect { |a| a[:pocketid] == listing['item_id'] }
      SysLogger.logger.info "[UPDATE] #{title} - #{listing['given_url']} - (#{idx + 1}/#{listings.count})"

      article['PocketID']   = listing['item_id']
      article['Name']       = title
      article['Body']       = listing['excerpt']
      article['Tags']       = listing['tags'].nil? ? "" : listing['tags'].values.collect { |t| t['tag'] }.join(',')
      article['URL']        = listing['given_url']
      article['added_at']   = Time.at(listing['time_added'].to_i).iso8601
      article['read_at']    = listing['read_at'].to_i > 0 ? Time.at(listing['read_at'].to_i).iso8601 : nil
      article['archived']   = listing['status'].to_s == '1'
      article['word_count'] = listing['word_count'].to_i
      article.save
    else
      SysLogger.logger.info "[CREATE] #{title} - #{listing['given_url']} - (#{idx + 1}/#{listings.count})"

      Article.new(
        PocketID: listing['item_id'],
        Name: title,
        Image: listing['images'].nil? ? [] : listing['images'].values.collect { |i| { url: i['src'] } },
        Body: listing['excerpt'],
        Tags: listing['tags'].nil? ? "" : listing['tags'].values.collect { |t| t['tag'] }.join(','),
        URL: listing['given_url'],
        added_at: Time.at(listing['time_added'].to_i).iso8601,
        read_at: listing['read_at'].to_i > 0 ? Time.at(listing['read_at'].to_i).iso8601 : nil,
        archived: listing['status'].to_s == '1',
        word_count: listing['word_count']
      ).create
    end
  end
rescue => e
  ScrappyStore.write('pocket_since_timestamp', original_since_timestamp)
  SysLogger.logger.error "#{e.class} => #{e.message}"
  raise e
end
