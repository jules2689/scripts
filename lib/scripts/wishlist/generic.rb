require 'metainspector'

module Wishlist
  class Generic
    PRICE_REGEX = /\$\s*[0-9,]+(?:\s*\.\s*\d{2})?/

    class << self
      def scrape(url)
        u_agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36'
        page = MetaInspector.new(url, headers: { 'User-Agent' => u_agent })
        {
          title: page.best_title,
          price: page.meta['og:price:amount'] || find_price(page.to_s),
          desc:  page.best_description,
          image: image(url, page),
          url: url
        }
      end

      private

      def image(url, page)
        if url.match(/structube.com/)
          page.to_s.match(%r{<img data-lazy=\\\"([^\s]*) })[1].gsub(%r{\\/}, '/')[0..-3]
        else
          page.images.best
        end
      end

      def find_price(content)
        m = content.match(PRICE_REGEX)
        m[0].gsub(/[\s$]/, '') if m[0]
      end
    end
  end
end
