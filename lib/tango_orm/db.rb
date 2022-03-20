# frozen_string_literal: true

require 'yaml'
require 'pg'
require "tango_orm/environment"
require "tango_orm/connection_pool"


module TangoOrm
  class DB
    attr_reader :config, :connection_pool

    def initialize
      @config = YAML.load(File.read("config/database.yml"))[ENVIRONMENT]
      @connection_pool = TangoOrm::ConnectionPool.instance
    end

    # def self.execute(&block)
    #   new.execute(&block)
    # end

    def execute
      Thread.handle_interrupt(Exception => :never) do
        connection = connection_pool.check_out { PG.connect(dbname: config['database']) }
        begin
          Thread.handle_interrupt(Exception => :immediate) do
            yield connection
          end
        ensure
          connection_pool.check_in
        end
      end
    end
  end
end
