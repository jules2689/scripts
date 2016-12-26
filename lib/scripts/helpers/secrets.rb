require 'json'

class Secrets
  def self.secrets
    JSON.parse(File.read("config/secrets.json"))
  end
end
