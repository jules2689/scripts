require "net/http"
require "uri"
require 'json'

module Wishlist
  class Shopify
    class << self
      def scrape(url)
        uri = URI(url)
        path = uri.path.end_with?('.json') ? uri.path : "#{uri.path}.json"
        request_url = "#{uri.scheme}://#{uri.host}#{path}"
        response = Net::HTTP.get_response(URI.parse(request_url))
        json = JSON.parse(response.body)

        query_parts = uri.query.split('&').map { |q| q.split('=') }
        variant_id = query_parts.select { |q| q.first == 'variant' }.last.to_i
        variant = variant_id ? json['product']['variants'][variant_id] : json['product']['variants'].first

        image = if variant_id
          i = j['product']['images'].select { |i| i['variant_ids'].include?(variant_id) }
          i.first['src'] unless i.empty?
        end
        image ||= json['product']['images'].first['src']

        {
          title: json['product']['title'],
          price: variant['price'],
          desc:  remove_html_tags(json['product']['body_html']),
          image: image,
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
