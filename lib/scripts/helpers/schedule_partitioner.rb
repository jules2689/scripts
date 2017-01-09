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

  def partition
    @articles.each do |article|
      minimum_bucket(article['read_time'].to_i) << article
    end
  end

  def minimum_bucket(value_to_add)
    candidate_buckets = @buckets.reject do |bucket|
      # Already over max bucket size
      value_of_bucket(bucket) >= @max_value ||
      # Too many articles
      bucket.size >= @max_size ||
      # Would go over size too much (unless this is the only article)
      (!bucket.empty? && value_of_bucket(bucket) + value_to_add >= @max_value + DEFAULT_VALUE)
    end

    if candidate_buckets.empty?
      @buckets << []
      candidate_buckets = @buckets
    end

    candidate_buckets.min_by { |bucket| value_of_bucket(bucket) }
  end

  def value_of_bucket(bucket)
    bucket.collect { |v| v["read_time"].to_i > 0 ? v['read_time'].to_i : DEFAULT_VALUE }.inject(&:+) || 0
  end
end
