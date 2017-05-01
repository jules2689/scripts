require "net/http"
require "uri"
require 'json'

module Wishlist
  class Shopify
    class << self
      def scrape(url)
        request_url = url.end_with?('.json') ? url : "#{url}.json" 
        response = Net::HTTP.get_response(URI.parse(request_url))
        json = JSON.parse(response.body)

        {
          title: json['product']['title'],
          price: json['product']['variants'].first['price'],
          desc:  remove_html_tags(json['product']['body_html']),
          image: json['product']['images'].first['src'],
          url: url
        }
      end

      private

      def remove_html_tags(html)
        re = /<("[^"]*"|'[^']*'|[^'">])*>/
        html.gsub(re, '').strip
      end
    end
  end
end
