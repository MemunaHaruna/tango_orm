# frozen_string_literal: true

require 'yaml'
require 'pg'
require "tango_orm/environment"
require "tango_orm/connection_pool"


module TangoOrm
  class DBConnection
    attr_reader :config, :connection_pool

    def initialize
      @config = YAML.load(File.read("config/database.yml"))[ENVIRONMENT]
      @connection_pool = TangoOrm::ConnectionPool.instance
    end

    def self.create
      new.create
    end

    def create
      connection_pool.call { PG.connect(dbname: config['database']) }
    end
  end
end
