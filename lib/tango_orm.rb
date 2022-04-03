# frozen_string_literal: true

require "tango_orm/version"
require "tango_orm/model"
require "tango_orm/config"

module TangoOrm
  class Error < StandardError; end
  class ConfigError < Error; end

  def self.config
    @config ||= configure
  end

  def self.configure(file_path = nil, env = nil)
    @config ||= Config.load(file_path, env)
  end
end
