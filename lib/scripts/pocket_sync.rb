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

def needs_update?(article, listing)
  return true if article['Name']       != title_from_listing(listing)
  return true if article['Body']       != listing['excerpt']
  return true if article['Tags']       != tags_from_listing(listing)
  return true if article['URL']        != listing['given_url']
  return true if article['read_at']    != listing['read_at'].to_i > 0 ? Time.at(listing['read_at'].to_i).iso8601 : nil
  return true if article['archived']   != (listing['status'].to_s != '0')
  return true if article['word_count'] != listing['word_count'].to_i
  false
end

def update_article(article, listing)
  article['Name']       = title_from_listing(listing)
  article['Body']       = listing['excerpt']
  article['Tags']       = tags_from_listing(listing)
  article['URL']        = listing['given_url']
  article['read_at']    = listing['read_at'].to_i > 0 ? Time.at(listing['read_at'].to_i).iso8601 : nil
  article['archived']   = listing['status'].to_s != '0'
  article['word_count'] = listing['word_count'].to_i
  article.save
end

def tags_from_listing(listing)
  listing['tags'].nil? ? "" : listing['tags'].values.collect { |t| t['tag'] }.join(',')
end

def title_from_listing(listing)
  return listing['resolved_title'] unless listing['resolved_title'].nil? || listing['resolved_title'].strip == ''
  return listing['given_title'] unless listing['given_title'].nil? || listing['given_title'].strip == ''
  listing['given_url']
end

SysLogger.logger.info "Starting Pocket sync with Airtable"

current_articles = Article.all
original_since_timestamp = ScrappyStore.read('pocket_since_timestamp', 1)
listings = PocketApi.fetch_listings.reject { |l| l['given_url'].nil? }

begin
  listings.each_with_index do |listing, idx|
    if article = current_articles.detect { |a| a[:pocketid] == listing['item_id'] }
      next unless needs_update?(article, listing)
      SysLogger.logger.info "[UPDATE] #{title_from_listing(listing)} - #{listing['given_url']} - (#{idx + 1}/#{listings.count})"
      update_article(article, listing)
    else
      SysLogger.logger.info "[CREATE] #{title_from_listing(listing)} - #{listing['given_url']} - (#{idx + 1}/#{listings.count})"
      Article.new(
        PocketID: listing['item_id'],
        Name: title_from_listing(listing),
        Image: listing['images'].nil? ? [] : listing['images'].values.collect { |i| { url: i['src'] } },
        Body: listing['excerpt'],
        Tags: tags_from_listing(listing),
        URL: listing['given_url'],
        added_at: Time.at(listing['time_added'].to_i).iso8601,
        read_at: listing['read_at'].to_i > 0 ? Time.at(listing['read_at'].to_i).iso8601 : nil,
        archived: listing['status'].to_s != '0',
        word_count: listing['word_count']
      ).create
    end
  end
rescue => e
  ScrappyStore.write('pocket_since_timestamp', original_since_timestamp)
  SysLogger.logger.error "#{e.class} => #{e.message}"
  raise e
end
