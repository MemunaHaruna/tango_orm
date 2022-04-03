# frozen_string_literal: true

require 'singleton'

module TangoOrm
  class ConnectionPool
    include Singleton

    class Error < ::RuntimeError; end
    class ConnectionTimeoutError < ConnectionPool::Error; end

    DEFAULT_MAX_POOL_SIZE = 5

    # number of seconds that a connection will be kept unused in the pool
    # before it is automatically disconnected (default 300 seconds).
    # Set this to zero to keep connections forever.
    IDLE_TIMEOUT = 300

    # interval to wait for a connection to become available before giving up
    # and raising a timeout error (default 5 seconds).
    CHECKOUT_TIMEOUT = 5
    CHECKOUT_RETRY_ATTEMPTS = 3

    # interval to periodically checkin connections belonging to inactive threads.
    # default 60 seconds
    REAPING_FREQUENCY = 60

    attr_accessor :max_size
    attr_reader :created_connections, :connection_queue, :idle_timeout, :checkout_timeout,
                :reaping_frequency, :key, :key_count, :mutex, :resource

    def initialize
      @config = TangoOrm.config
      @created_connections = 0
      @connection_queue = Queue.new
      @max_size = @config[:pool] || DEFAULT_MAX_POOL_SIZE
      @idle_timeout = @config[:idle_timeout] || IDLE_TIMEOUT
      @checkout_timeout = @config[:checkout_timeout] || CHECKOUT_TIMEOUT
      @reaping_frequency = @config[:reaping_frequency] || REAPING_FREQUENCY
      @key = :"pool-#{self.object_id}"
      @key_count = :"pool-#{self.object_id}-count"
      @mutex = Mutex.new
      @resource = ConditionVariable.new
    end

    def self.instance
      @@instance ||= new
    end

    # def call(&connector)
    #   if !pool_size_limit_reached?
    #     create_new_connection(&connector)
    #   else
    #     retry_connection(&connector)
    #   end
    # end

    def self.stat
      {
        max_size: instance.max_size,
        created_connections: instance.created_connections,
        # busy: instance.created_connections - instance.idle_connections,
        idle: instance.idle_connections,
        checkout_timeout: instance.checkout_timeout,
        idle_timeout: instance.idle_timeout,
        reaping_frequency: instance.reaping_frequency
      }
    end

    def check_out(&connector)
      # inspiration: https://github.com/mperham/connection_pool

      if ::Thread.current[key]
        # if the current thread wants another connection, just return its current connection
        ::Thread.current[key_count] += 1
        ::Thread.current[key]
      else
        ::Thread.current[key_count] = 1
        ::Thread.current[key] = create_connection(&connector)
      end
    end

    def check_in(thread = nil)
      # inspiration: https://github.com/mperham/connection_pool

      thread = thread || ::Thread.current
      if thread[key]
        if thread[key_count] == 1
          return_connection(thread)
          thread[key] = nil
          thread[key_count] = nil
        else
          # don't checkin the connection just yet
          thread[key_count] -= 1
        end
      else
        # raise ConnectionPool::Error, "no checked out connections"
      end

      # nil
    end

    def close_open_connections!
      return if idle_connections == 0
      allowed_idle_duration = current_time + idle_timeout

      mutex.synchronize do
        while idle_connections > 0
          if current_time - allowed_idle_duration >= 0
            conn = connection_queue.pop
            conn.close
          end
        end
      end
    end

    def idle_connections
      connection_queue.length
    end

    private

    # attr_reader :created_connections, :connection_queue, :idle_timeout, :checkout_timeout,
    #             :reaping_frequency, :key, :key_count, :mutex, :resource

    def pool_size_limit_reached?
      @created_connections >= max_size
    end

    def return_connection(thread)
      mutex.synchronize do
        connection_queue.push(thread[key])
        resource.broadcast
      end
    end

    def create_connection(&connector)
      # idle_connection = active_connections.find{|conn| !conn.is_busy }
      # return idle_connection if idle_connection
      # return if pool_size_limit_reached?

      # connection = connector.call
      # active_connections << connection
      # connection

      allowed_wait_duration = current_time + checkout_timeout
      timeout_msg = "could not obtain a database connection within #{checkout_timeout} seconds. "\
                    "The pool size is currently #{max_size}; consider increasing it"
      mutex.synchronize do
        loop do
          return connection_queue.pop unless connection_queue.empty?

          connection = create_unless_max_size_reached(&connector)
          return connection if connection

          to_wait = allowed_wait_duration - current_time
          raise ConnectionTimeoutError, timeout_msg if to_wait <= 0
          resource.wait(mutex, to_wait)
        end
      end
    end

    def current_time
      # https://blog.dnsimple.com/2018/03/elapsed-time-with-ruby-the-right-way/
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def create_unless_max_size_reached(&connector)
      unless pool_size_limit_reached?
        connection = connector.call
        @created_connections += 1
        connection
      end
    end

    # def retry_connection(&connector)
    #   allowed_attempts = CHECKOUT_RETRY_ATTEMPTS
    #   start_time = Time.now
    #   new_connection = nil
    #   timeout_msg = "could not obtain a database connection within 5 seconds. "\
    #                 "The pool size is currently #{max_size}; consider increasing it"

    #   while allowed_attempts > 0
    #     elapsed_time_in_seconds = (Time.now - start_time)
    #     break if elapsed_time_in_seconds > checkout_timeout

    #     new_connection = create_new_connection
    #     break if new_connection && active_connections.include?(new_connection)
    #     allowed_attempts -= 1
    #   end

    #   if !new_connection && !active_connections.include?(new_connection)
    #     raise ConnectionTimeoutError, ": #{timeout_msg}"
    #   end
    # end
  end
end

# Reaper thread to release connections from inactive threads back to the pool
# Thread.new do
#   pool_instance = TangoOrm::ConnectionPool.instance
#   reaping_frequency = pool_instance.send(:reaping_frequency)

#   loop do
#     puts "...checking in inactive threads' connections after #{reaping_frequency} seconds"
#     inactive_threads = Thread.list.select{|thr| thr.stop? }
#     inactive_threads.each {|it| pool_instance.check_in(it) }
#     sleep(reaping_frequency)
#   end
# end

# # Close idle connections after #{idle_timeout} seconds
# Thread.new do
#   pool_instance = TangoOrm::ConnectionPool.instance
#   idle_timeout = pool_instance.send(:idle_timeout)

#   loop do
#     puts "...closing idle connections every #{idle_timeout} seconds"
#     pool_instance.close_open_connections!
#     sleep(idle_timeout)
#   end
# end


# TangoOrm::ConnectionPool.stat
# db1 = TangoOrm::DB.new
# db2 = TangoOrm::DB.new
# db3 = TangoOrm::DB.new
# stat

# db1.execute { |conn| puts "#{conn}: something" }
# db2.execute { |conn| puts "#{conn}: another thing" }
# db3.execute { |conn| puts "#{conn}: last thing" }
# TangoOrm::ConnectionPool.stat
