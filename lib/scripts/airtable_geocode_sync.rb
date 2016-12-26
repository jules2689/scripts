require "net/http"
require "uri"
require_relative 'helpers/sys_logger'
require_relative 'helpers/secrets'
require 'airrecord'

class Restaurant < Airrecord::Table
  self.api_key = Secrets.secrets["airtable_api_key"]
  self.base_key = Secrets.secrets["airtable_restaurant_app_id"]
  self.table_name = Secrets.secrets["airtable_restaurant_table_id"]
end

Restaurant.all.each do |restaurant|
  if restaurant["Latitude"].nil? || restaurant["Longitude"].nil?
    SysLogger.logger.info "Geocoding Restaurant #{restaurant[:name]}"

    # Parse out Geocode
    url = "http://geocoder.ca/?locate=#{CGI.escape(restaurant[:address])}&json=true"
    uri = URI.parse(url)
    response = Net::HTTP.get_response(uri)
    json_response = JSON.parse(response.body)

    if json_response.key?("error")
      SysLogger.logger.info "-> Error parsing address: #{json_response['error']}"
    else
      SysLogger.logger.info "-> Received geocode"
      restaurant['Latitude'] = json_response["latt"].to_f
      restaurant['Longitude'] = json_response["longt"].to_f
      restaurant.save
      SysLogger.logger.info "-> Successfully updated"
    end
  else
    SysLogger.logger.info "Restaurant #{restaurant[:name]} already geocoded"
  end
end
