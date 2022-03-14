# frozen_string_literal: true

require 'pry-byebug'
require 'singleton'
require 'yaml'
require "tango_orm/environment"


module TangoOrm
  class ConnectionPool
    include Singleton

    class ConnectionTimeoutError < StandardError; end

    DEFAULT_POOL_SIZE = 5

    # number of seconds that a connection will be kept unused in the pool before it is automatically disconnected (default 300 seconds). Set this to zero to keep connections forever.
    IDLE_TIMEOUT = 300

    # number of seconds to wait for a connection to become available before giving up and raising a timeout error (default 5 seconds).
    CHECKOUT_TIMEOUT = 5
    CHECKOUT_RETRY_ATTEMPTS = 3

    attr_reader :active_connections, :idle_timeout, :checkout_timeout
    attr_accessor :pool_size

    def initialize
      @config = YAML.load(File.read("config/database.yml"))[ENVIRONMENT]
      @active_connections = []
      @pool_size = @config[:pool] || DEFAULT_POOL_SIZE
      @idle_timeout = @config[:idle_timeout] || IDLE_TIMEOUT
      @checkout_timeout = @config[:checkout_timeout] || CHECKOUT_TIMEOUT
    end

    def self.instance
      @@instance ||= new
    end

    def call(&connector)
      # Note i'm not doing a checkin, checkout logic. All connections here are checked out and removed after idle_timeout, if idle

      if !pool_size_limit_reached?
        create_new_connection(&connector)
      else
        retry_connection(&connector)
      end
    end

    def self.stat
      busy_connections = instance.active_connections.select(&:is_busy).count
      idle_connections = instance.active_connections.length - busy_connections
      {
        pool_size: instance.pool_size,
        connections: instance.active_connections,
        busy: busy_connections,
        idle: idle_connections,
        checkout_timeout: instance.checkout_timeout,
        idle_timeout: instance.idle_timeout
      }
    end

    private

    def pool_size_limit_reached?
      active_connections.length >= pool_size
    end

    def create_new_connection(&connector)
      idle_connection = active_connections.find{|conn| !conn.is_busy }
      return idle_connection if idle_connection
      return if pool_size_limit_reached?

      connection = connector.call
      active_connections << connection
      connection
    end

    def retry_connection(&connector)
      allowed_attempts = CHECKOUT_RETRY_ATTEMPTS
      start_time = Time.now
      new_connection = nil
      timeout_msg = "could not obtain a database connection within 5 seconds. "\
                    "The pool size is currently #{pool_size}; consider increasing it"

      while allowed_attempts > 0
        elapsed_time_in_seconds = (Time.now - start_time)
        break if elapsed_time_in_seconds > checkout_timeout

        new_connection = create_new_connection
        break if new_connection && active_connections.include?(new_connection)
        allowed_attempts -= 1
      end

      if !new_connection && !active_connections.include?(new_connection)
        raise ConnectionTimeoutError, ": #{timeout_msg}"
      end
    end
  end
end

Thread.new do
  pool_instance = TangoOrm::ConnectionPool.instance
  active_connections = pool_instance.active_connections
  idle_timeout = pool_instance.idle_timeout

  puts "...checking for idle connections, to be closed after #{idle_timeout} seconds"
  loop do
    active_connections.each do |conn|
      next if conn.is_busy
      sleep(idle_timeout)

      if !conn.is_busy
        conn.close
        active_connections.delete(conn)
      end
    end
    sleep(3)
  end
end

# TangoOrm::ConnectionPool.stat
# conn1 = TangoOrm::DBConnection.new
# conn2 = TangoOrm::DBConnection.new
# conn3 = TangoOrm::DBConnection.new
# stat

# conn1.create
# conn2.create
# conn3.create
# TangoOrm::ConnectionPool.stat

# conn1.connection_pool.active_connections
# conn2.connection_pool.active_connections
# conn3.connection_pool.active_connections
# TangoOrm::ConnectionPool.instance.active_connections
