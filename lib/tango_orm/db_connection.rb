require 'yaml'
require 'pg'
require "tango_orm/environment"

module TangoOrm
  class DBConnection
    def self.set_connection
      PG.connect(dbname: config['database'])
    end

    private

    def self.config
      @@config ||= YAML.load(File.read("config/database.yml"))[ENVIRONMENT]
    end
  end
end
