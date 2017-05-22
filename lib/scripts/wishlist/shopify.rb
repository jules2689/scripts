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

        if uri.query
          query_parts = uri.query.split('&').map { |q| q.split('=') }
          variant_id = query_parts.select { |q| q.first == 'variant' }.first.last.to_i
          variant = if variant_id
            json['product']['variants'].select { |v| v['id'] == variant_id }.first
          else
            json['product']['variants'].first
          end
        end

        image = if variant_id
          i = json['product']['images'].select do |i|
            i['variant_ids'].include?(variant_id)
          end
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
