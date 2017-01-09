require 'airrecord'

class Tag < Airrecord::Table
  self.api_key = Secrets.secrets['airtable_api_key']
  self.base_key = Secrets.secrets['airtable_pocket_app_id']
  self.table_name = "tblyayGiUi7vW27Lc"
end
