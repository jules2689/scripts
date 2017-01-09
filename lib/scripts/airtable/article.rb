require 'airrecord'

class Article < Airrecord::Table
  self.api_key = Secrets.secrets['airtable_api_key']
  self.base_key = Secrets.secrets['airtable_pocket_app_id']
  self.table_name = Secrets.secrets['airtable_pocket_table_id']

  class << self
    def update_article(article, listing, tag_ids)
      article['Name']         = title_from_listing(listing)
      article['Body']         = listing['excerpt']
      article['Tags']         = tag_ids
      article['URL']          = listing['given_url']
      article['read_at']      = listing['read_at'].to_i > 0 ? Time.at(listing['read_at'].to_i).iso8601 : nil
      article['archived']     = listing['status'].to_s != '0'
      article['word_count']   = listing['word_count'].to_i
      article['read_time']    = estimated_read_time(listing)
      article['time_updated'] = listing['time_updated'].to_i > 0 ? Time.at(listing['time_updated'].to_i).iso8601 : nil
      article.save
    end

    def create_article(listing, tag_ids)
      Article.new(
        PocketID: listing['item_id'],
        Name: title_from_listing(listing),
        Image: images_from_listing(listing),
        Body: listing['excerpt'],
        Tags: tag_ids,
        URL: listing['given_url'],
        added_at: Time.at(listing['time_added'].to_i).iso8601,
        read_at: listing['read_at'].to_i > 0 ? Time.at(listing['read_at'].to_i).iso8601 : nil,
        archived: listing['status'].to_s != '0',
        word_count: listing['word_count'],
        read_time: estimated_read_time(listing),
        time_updated: listing['time_updated'].to_i > 0 ? Time.at(listing['time_updated'].to_i).iso8601 : nil
      ).create
    end
  end
end
