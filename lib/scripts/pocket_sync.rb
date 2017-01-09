require 'net/http'
require 'uri'
require 'time'
require_relative 'helpers/sys_logger'
require_relative 'helpers/secrets'
require_relative 'helpers/pocket_api'
require_relative 'helpers/schedule_partitioner'
require_relative 'airtable/article'
require_relative 'airtable/tag'

class PocketToAirtable
  def initialize
    @tags = Tag.all
    @articles = Article.all
  end

  def sync
    original_since_timestamp = ScrappyStore.read('pocket_since_timestamp', 1)
    listings = PocketApi.fetch_listings

    begin
      listings.each_with_index do |listing, idx|
        article = @articles.detect { |a| a[:pocketid] == listing['item_id'] }
        tag_ids = tags_from_listing(listing)

        if listing['status'].to_s == '2' # Pocket API indicates this as "deleted"
          next if article.nil?
          SysLogger.logger.info "[DELETE] #{listing['item_id']} - (#{idx + 1}/#{listings.count})"
          article.destroy
        elsif article.nil? # We have no article currently, so create one
          SysLogger.logger.info "[CREATE] #{listing['item_id']} - #{title_from_listing(listing)} - (#{idx + 1}/#{listings.count})"
          Article.create_article(listing, tag_ids)
        else # Otherwise, we have one and it needs updating
          next unless article['time_updated'].to_time.to_i != listing['time_updated'].to_i
          SysLogger.logger.info "[UPDATE] #{listing['item_id']} - #{title_from_listing(listing)} - (#{idx + 1}/#{listings.count})"
          Article.update_article(article, listing, tag_ids)
        end
      end
    rescue => e
      ScrappyStore.write('pocket_since_timestamp', original_since_timestamp)
      SysLogger.logger.error "#{e.class} => #{e.message}"
    end
  end

  def update_scheduled_dates
    # Schedule Articles
    SysLogger.logger.info 'Scheduling all articles'
    @articles = Article.all # Need to update due to the sync

    # Determine what we need to schedule
    articles_to_schedule = @articles.reject { |a| a[:archived] || a[:scheduled_at] }
    SysLogger.logger.info "#{articles_to_schedule.size} article(s) to schedule"

    # Prefill buckets with articles after today
    now = DateTime.now
    scheduled_articles = @articles.select do |a|
      a[:scheduled_at].to_i >= Time.new(now.year, now.month, now.day, 0, 0, 0, now.zone).to_i
    end
    scheduled_articles = scheduled_articles.group_by { |a| a[:scheduled_at].to_i }

    # Partition the articles to schedule
    partition = SchedulePartitioner.new(articles_to_schedule, prefilled_buckets: scheduled_articles.values, max_value: 1500, max_size: 2)
    partition.partition
    schedule_parition(partition)
  end

  private

  def tags_from_listing(listing)
    tag_names = listing['tags'].nil? ? [] : listing['tags'].values.collect { |t| t['tag'] }
    tag_names.map do |name|
      unless tag = @tags.detect { |t| t[:name] == name }
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

  def schedule_parition(partition)
    # Candidate dates are all dates over the next 180 days
    start_date = Date.today
    candidate_dates = (1..180).to_a.map { |d| (start_date + d).to_date }
    scheduled_dates = @articles.collect { |a| a[:scheduled_at] ? a[:scheduled_at].to_i : nil }.reject(&:nil?)

    partition.to_h.each do |_, bucket|
      next if bucket[:items].all? { |a| !a[:scheduled_at].nil? }

      SysLogger.logger.info "Scheduling #{bucket[:items].size} articles with an estimated read time of #{bucket[:value] / 60}min"
      if article_with_date = bucket[:items].detect { |b| !b[:scheduled_at].nil? }
        # This was a pre-filled bucket, so assign the same date to everything else
        bucket[:items].each do |article|
          article['scheduled_at'] = Time.at(article_with_date[:scheduled_at].to_i).to_date
          article.save
        end
      else
        # This was not a pre-filled bucket, so assign a candidate date
        # Iterating through the bucket, find the dates that aren't currently taken
        # Once an appropriate date is found, update all articles for that bucket to reflect it
        candidate_dates.each do |candidate_date|
          candidate_dates -= [candidate_date]
          next if scheduled_dates.include?(candidate_date.to_time.to_i)

          SysLogger.logger.info "Scheduling for #{candidate_date}"
          bucket[:items].each do |article|
            article['scheduled_at'] = candidate_date
            article.save
          end
          break
        end
      end
    end
  end
end

SysLogger.logger.info "Starting Pocket sync with Airtable"
pta = PocketToAirtable.new
pta.sync
pta.update_scheduled_dates
SysLogger.logger.info 'Finished Sync'
