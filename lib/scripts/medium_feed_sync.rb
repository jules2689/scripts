require 'nokogiri'
require 'net/http'
require 'json'
require_relative 'helpers/sys_logger'
require_relative 'helpers/secrets'

module MediumFeed
  WEBSITE_URL = "https://jnadeau.ca/posts/create_medium_post.json"
  MEDIUM_FEED_URL = "https://medium.com/feed/@jules2689"

  class << self
    def sync
      fetch_posts.each { |post| sync_post(post) }
    end

    private

    def sync_post(post)
      SysLogger.logger.info "Syncing post #{post[:title]}"

      form_params = { user_token: Secrets.secrets["website_api_key"] }
      post.each { |key, val| form_params["post[#{key}]"] = val }

      uri = URI.parse(WEBSITE_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri.request_uri)
      request.set_form_data(form_params)
      response = http.request(request)

      if response.code.to_i < 299
        SysLogger.logger.info "Successful sync!"
      else
        SysLogger.logger.warn "Errors: #{response.body}"
      end
    end

    def fetch_posts
      SysLogger.logger.info "Syncing posts from Medium"
      uri = URI.parse(MEDIUM_FEED_URL)
      response = Net::HTTP.get_response(uri)
      doc = Nokogiri::XML(response.body)

      posts = []
      doc.search('item').each do |item|
        post = {
          title: item.search('title').first.text,
          medium_url: item.search('link').first.text,
          published_date: item.search('pubDate').first.text,
          tag_list: item.search('category').map(&:text).join(',')
        }
        post[:header_image_url] = fetch_image(post[:medium_url])
        posts << post
      end
      posts
    end

    def fetch_image(url)
      SysLogger.logger.info "Fetching image for post"
      uri = URI.parse(url)
      response = Net::HTTP.get_response(uri)
      doc = Nokogiri::HTML(response.body)

      if article = doc.xpath('//article/div').first
        if img = article.search('img').first
          SysLogger.logger.info "=> Found #{img.attr('src').strip}"
          return img.attr('src').strip
        end
      end

      SysLogger.logger.info "=> Found nothing"
    end
  end
end

MediumFeed.sync
