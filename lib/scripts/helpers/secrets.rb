require 'json'

class Secrets
  def self.secrets
    file_path = File.expand_path("../../../../config/secrets.json", __FILE__)
    JSON.parse(File.read(file_path))
  end
end
