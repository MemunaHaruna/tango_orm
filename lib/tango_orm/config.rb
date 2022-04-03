# frozen_string_literal: true

require 'pathname'
require 'yaml'

module TangoOrm
  class Config

    # TO-DO: DRY
    PG_EXT_OPTIONS = %w(adapter database host port user password).freeze
    PG_INT_OPTIONS = %w(adapter dbname host port user password).freeze

    attr_writer :file_path, :env

    def initialize(file_path, env)
      @file_path = file_path || default_config_file
      @env = env || default_environment
    end

    def self.load(file_path, env)
      new(file_path, env).load
    end

    def load
      # TO-DO: support DATABASE_URL
      config = {}
      yaml = YAML.load(File.read(file_path))[env]
      config.merge!(pg_config(yaml)) if yaml
    rescue Errno::ENOENT => e
      raise TangoOrm::ConfigError, error_message(e.message)
    rescue Psych::SyntaxError => e
      raise TangoOrm::ConfigError, error_message(e.message)
    end

    private

    attr_reader :file_path, :env

    def pg_config(options)
      # TO-DO: add support for DBs other than postgres

      keys = PG_EXT_OPTIONS
      keys.each_with_object({}) do |key, memo|
        config_key = pg_config_key(key.to_sym)
        memo[config_key.to_sym] = options[key] if options[key]
      end
    end

    def pg_config_key(name)
      {
        adapter: :adapter,
        database: :dbname,
        host: :host,
        port: :port,
        user: :user,
        password: :password,
        url: :url
      }[name]
    end

    def default_environment
      ENV.fetch("APP_ENV", "development")
    end

    def default_config_file
      root_path.join('config', 'database.yml').to_path
    end

    def root_path
      Pathname.new(defined?(Rails) ? Rails.root : '.')
    end

    def error_message(error)
      "Could not load database configuration: #{error}.\n"\
      "Verify #{file_path} is correct."
    end
  end
end
