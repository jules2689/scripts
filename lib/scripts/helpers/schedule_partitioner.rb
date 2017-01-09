class SchedulePartitioner
  attr_accessor :buckets
  DEFAULT_VALUE = 300

  def initialize(articles, prefilled_buckets: [], max_value:, max_size:)
    @articles = articles.sort_by { |v| v['read_time'].to_i > 0 ? -v['read_time'].to_i : -DEFAULT_VALUE }
    @max_value = max_value
    @max_size = max_size
    @buckets = prefilled_buckets
  end

  def to_h
    @buckets.each_with_object({}).with_index do |(bucket, h), idx|
      h[idx] = {
        items: bucket,
        value: value_of_bucket(bucket)
      }
    end
  end

  # Simply put, this function will shove articles into the "minimum bucket"
  # This will greedily sort the articles until such a time that all are exhausted
  # and sorted. We let the minimum bucket function know the read time of the article
  # to help aid the decision so we don't go over max value by very much
  def partition
    @articles.each do |article|
      minimum_bucket(article['read_time'].to_i) << article
    end
  end

  # The minimum bucket is the bucket with the least value (determined by read time)
  # There is a max value set at initialization and a max size for the entries in a bucket
  # We can go over the max value by a little bit to help
  def minimum_bucket(value_to_add)
    candidate_buckets = @buckets.reject do |bucket|
      # Already over max bucket size
      value_of_bucket(bucket) >= @max_value ||
      # Too many articles
      bucket.size >= @max_size ||
      # Would go over size too much (unless this is the only article)
      (!bucket.empty? && value_of_bucket(bucket) + value_to_add >= @max_value + DEFAULT_VALUE)
    end

    # If we have no candidate buckets, we've exhausted all current buckets, so add another
    # Candidate buckets will now be all buckets. The min_by function below will get the empty bucket
    if candidate_buckets.empty?
      @buckets << []
      candidate_buckets = @buckets
    end

    candidate_buckets.min_by { |bucket| value_of_bucket(bucket) }
  end

  # The value of a bucket is the sum of all read times of articles, if an article has a 0 minute read time
  # assume it is worth DEFAULT_VALUE
  def value_of_bucket(bucket)
    bucket.collect { |v| v["read_time"].to_i > 0 ? v['read_time'].to_i : DEFAULT_VALUE }.inject(&:+) || 0
  end
end
