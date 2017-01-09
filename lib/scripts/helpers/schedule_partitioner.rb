class SchedulePartitioner
  attr_accessor :buckets

  def initialize(articles, max_value, max_size)
    @articles = articles.sort_by { |v| -v['read_time'] }
    @max_value = max_value
    @max_size = max_size
    @buckets = []
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
      minimum_bucket << article
    end
  end

  def minimum_bucket
    candidate_buckets = @buckets.reject { |bucket| value_of_bucket(bucket) >= @max_value || bucket.size >= @max_size }
    if candidate_buckets.empty?
      @buckets << []
      candidate_buckets = [@buckets.last]
    end
    candidate_buckets.min_by { |bucket| value_of_bucket(bucket) }
  end

  def value_of_bucket(bucket)
    bucket.collect { |v| v["read_time"] }.inject(&:+) || 0
  end
end
