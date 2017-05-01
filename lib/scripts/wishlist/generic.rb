require 'metainspector'

module Wishlist
  class Generic
    PRICE_REGEX = /\$\s*[0-9,]+(?:\s*\.\s*\d{2})?/

    class << self
      def scrape(url)
        u_agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36'
        page = MetaInspector.new(url, headers: { 'User-Agent' => u_agent })

        {
          title: title(url, page),
          price: find_price(url, page),
          desc:  page.best_description,
          image: image(url, page),
          url: url
        }
      end

      private

      def title(url, page)
        case url
        when /canadacomputers.com/
          page.best_title.split(' | ').last
        else
          page.best_title
        end
      end

      def image(url, page)
        case url
        when /structube.com/
          page.to_s.match(%r{<img data-lazy=\\\"([^\s]*) })[1].gsub(%r{\\/}, '/')[0..-3]
        when /canadacomputers.com/
          images = page.images.with_size
          url = images.select { |x| x.first.include?('/Products/') }.max_by(&:last).first
          current_size = url.match(%r{Products/([\dx]+)})[1]
          url.gsub(current_size, '1000x1000')
        else
          page.images.best
        end
      end

      def find_price(url, page)
        case url
        when /canadacomputers.com/
          noko_page = Nokogiri::HTML(page.to_s)
          noko_page.css('#SalePrice').text[1..-1].strip
        else
          price = page.meta['og:price:amount']
          return price if price

          m = page.to_s.match(PRICE_REGEX)
          m[0].gsub(/[\s$]/, '') if m[0]
        end
      end
    end
  end
end
