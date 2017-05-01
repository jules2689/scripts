require 'nokogiri'
require 'open-uri'
require 'json'

module Wishlist
  class Amazon
    class << self
      def scrape(url)
        u_agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36'
        content = open(url, "User-Agent" => u_agent)
        page = Nokogiri::HTML(content)

        price = page.css('#priceblock_dealprice').text
        price = page.css('#priceblock_ourprice').text if price == '' || price.nil?
        price.gsub!(/([\s$]|CDN)/, '')

        desc = page.css('#productDescription .text-block').text.force_encoding("ISO-8859-1")
        desc = page.css('#productDescription p').text if desc == '' || desc.nil?

        {
          title: page.title,
          price: price,
          desc:  squish!(remove_html_tags(desc)),
          image: page.css('#imgTagWrapperId img').attr('data-old-hires').value,
          url: url
        }
      end

      private

      def remove_html_tags(html)
        re = /<("[^"]*"|'[^']*'|[^'">])*>/
        html.gsub(re, '')
      end

      def squish!(s)
        s.gsub!(/[[:space:]]+/, ' ')
        s.strip!
        s
      end
    end
  end
end
