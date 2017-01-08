require 'yaml'

class ScrappyStore
  def self.read(name, fallback = nil)
    yml = YAML.load_file(yaml_path)
    yml[name] || fallback
  rescue
    fallback
  end

  def self.write(name, value)
    yml = YAML.load_file(yaml_path) || {}
    yml[name] = value
    File.write(yaml_path, yml.to_yaml)
  end

  def self.yaml_path
    File.expand_path("../../../../config/scrappy_store.yml", __FILE__)
  end
end
