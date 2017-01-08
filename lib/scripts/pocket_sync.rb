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

class Tag < Airrecord::Table
  self.api_key = Secrets.secrets['airtable_api_key']
  self.base_key = Secrets.secrets['airtable_pocket_app_id']
  self.table_name = "tblyayGiUi7vW27Lc"
end

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

def tags_from_listing(listing, tags)
  tag_names = listing['tags'].nil? ? [] : listing['tags'].values.collect { |t| t['tag'] }
  tag_names.map do |name|
    unless tag = tags.detect { |t| t[:name] == name }
      tag = Tag.new(Name: name)
      tag.create
    end
    tag.id
  end
end

def title_from_listing(listing)
  return listing['resolved_title'] unless listing['resolved_title'].nil? || listing['resolved_title'].strip == ''
  return listing['given_title'] unless listing['given_title'].nil? || listing['given_title'].strip == ''
  listing['given_url']
end

def images_from_listing(listing)
  listing['images'].nil? ? [] : listing['images'].values.collect { |i| { url: i['src'] } }
end

# Read time is based on the average reading speed of an adult (roughly 275 WPM).
# We take the total word count of a post and translate it into minutes.
# Then, we add 12 seconds for each inline image.

# Additional notes:
# Our original read time calculation was geared toward “slow” images, like comics,
# where you would really want to sit down and invest in the image.
# This resulted in articles with crazy big read times. For instance,
# this article containing 140 images was clocking in at a whopping 87 minute read.
# So we amended our read time calculation to count 12 seconds for the first image, 11 for the second,
# and minus an additional second for each subsequent image.
# Any images after the tenth image are counted at three seconds.
def estimated_read_time(listing)
  seconds_for_words = listing['word_count'].to_i / 275 * 60
  images_count = images_from_listing(listing).size

  # x refers to the first 9 images and is used to calculate the combined total of (12 + 11 + 10 ...)
  # every image after 10 counts as 3 seconds, hence the second part of the equation
  x = [images_count, 10].min
  seconds_for_images = (12.5 * x - 0.5 * x**2) + [0, images_count - 10].max * 3
  seconds_for_words + seconds_for_images
end

SysLogger.logger.info "Starting Pocket sync with Airtable"

tags = Tag.all
current_articles = Article.all
original_since_timestamp = ScrappyStore.read('pocket_since_timestamp', 1)
listings = PocketApi.fetch_listings

begin
  listings.each_with_index do |listing, idx|
    article = current_articles.detect { |a| a[:pocketid] == listing['item_id'] }
    if listing['status'].to_s == '2' # Pocket API indicates this as "deleted"
      next if article.nil?
      SysLogger.logger.info "[DELETE] #{listing['item_id']} - (#{idx + 1}/#{listings.count})"
      article.destroy
    elsif article.nil? # We have no article currently, so create one
      SysLogger.logger.info "[CREATE] #{listing['item_id']} - #{title_from_listing(listing)} - (#{idx + 1}/#{listings.count})"
      create_article(listing, tags_from_listing(listing, tags))
    else # Otherwise, we have one and it needs updating
      tag_ids = tags_from_listing(listing, tags)
      next unless article['time_updated'].to_time.to_i != listing['time_updated'].to_i
      SysLogger.logger.info "[UPDATE] #{listing['item_id']} - #{title_from_listing(listing)} - (#{idx + 1}/#{listings.count})"
      update_article(article, listing, tag_ids)
    end
  end
rescue => e
  ScrappyStore.write('pocket_since_timestamp', original_since_timestamp)
  SysLogger.logger.error "#{e.class} => #{e.message}"
end
SysLogger.logger.info 'Finished Sync'
