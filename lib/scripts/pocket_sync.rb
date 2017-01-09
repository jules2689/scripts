require 'net/http'
require 'uri'
require 'time'
require_relative 'helpers/sys_logger'
require_relative 'helpers/secrets'
require_relative 'helpers/pocket_api'
require_relative 'helpers/schedule_partitioner'
require_relative 'airtable/article'

class PocketToAirtable
  def initialize
    @articles = Article.all
  end

  def sync
    original_since_timestamp = ScrappyStore.read('pocket_since_timestamp', 1)
    listings = PocketApi.fetch_listings

    begin
      listings.each_with_index do |listing, idx|
        article = @articles.detect { |a| a[:pocketid] == listing['item_id'] }
        # Pocket API indicates this as "deleted"
        if listing['status'].to_s == '2'
          next if article.nil?
          SysLogger.logger.info "[DELETE] #{listing['item_id']} - (#{idx + 1}/#{listings.count})"
          article.destroy
        # We have no article currently, so create one
        elsif article.nil?
          SysLogger.logger.info "[CREATE] #{listing['item_id']} - #{listing['given_url']} - (#{idx + 1}/#{listings.count})"
          Article.create_article(listing)
        # Otherwise, we have one and it needs updating
        else
          next unless article['time_updated'].to_time.to_i != listing['time_updated'].to_i
          SysLogger.logger.info "[UPDATE] #{listing['item_id']} - #{listing['given_url']} - (#{idx + 1}/#{listings.count})"
          Article.update_article(article, listing)
        end
      end
    rescue => e
      ScrappyStore.write('pocket_since_timestamp', original_since_timestamp)
      SysLogger.logger.error "#{e.class} => #{e.message}\n#{e.backtrace.join("\n")}"
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
          next unless article['scheduled_at'].nil?
          article['scheduled_at'] = article_with_date['scheduled_at'].strftime("%Y/%m/%d")
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
