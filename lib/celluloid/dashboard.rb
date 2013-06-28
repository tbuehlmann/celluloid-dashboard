require 'forwardable'
require 'json'
require 'ostruct'
require 'singleton'
require 'timeout'
require 'webrick'

require 'celluloid/autostart'
require 'sinatra/base'
require 'sinatra/content_for'
require 'sinatra/flash'
require 'slim'

require 'celluloid/dashboard/application'
require 'celluloid/dashboard/notifier'
require 'celluloid/dashboard/version'

module Celluloid
  class Dashboard
    include Singleton
    extend SingleForwardable

    CONFIG_DEFAULTS = {
      server: 'webrick',
      host: 'localhost',
      port: 8090,
      notification_log_size: 100
    }.freeze

    class << self
      def configure(&block)
        if running?
          raise 'The Dashboard server is already running.'
        else
          yield instance.config
          self
        end
      end

      def start
        instance.start ? self : nil
      end

      def stop
        instance.stop ? self : nil
      end
    end

    def_delegator :instance, :running?

    attr_reader :config

    def initialize
      @config = OpenStruct.new(CONFIG_DEFAULTS)
      @thread = nil
      @at_exit_setup = false
    end

    # Starts the Dashboard server.
    def start
      return if running?
      setup_exit_handler
      @notifier = Notifier.new(@config.notification_log_size)

      @thread = ::Thread.new do
        begin
          options = sinatra_options

          Application.run!(options) do |server|
            ::Thread.current[:server] = server
            ::Thread.current[:handler_name] = options[:server]
            Celluloid::Logger.info('Celluloid::Dashboard server started.')
          end
        rescue Errno::EADDRINUSE
          Celluloid::Logger.error("Celluloid::Dashboard server could not be started (port #{@config.port} already in use).")
        rescue StandardError => e
          Celluloid::Logger.error("Celluloid::Dashboard server could not be started (#{e.class}: #{e.message}).")
        end

        stop
      end
    end

    # Stops the Dashboard server.
    def stop
      return unless running?

      # If stopping the server takes too much time, just kill
      # the thread directly.
      begin
        Timeout.timeout(5) do
          Application.quit!(@thread[:server], @thread[:handler_name])
        end
      rescue; end

      @thread.kill
      @notifier.terminate
      Application.clear_connections
      Celluloid::Logger.info('Celluloid::Dashboard server stopped.')
    end

    # Determines whether the Dashboard server is running or not.
    def running?
      @thread && @thread.alive? ? true : false
    end

    private

    def sinatra_options
      {
        server: @config.server,
        bind: @config.host,
        port: @config.port
      }
    end

    # Sets up an at_exit handler so the Dashboard server
    # tries to stop gracefully before exiting the program.
    def setup_exit_handler
      unless @at_exit_setup
        at_exit { stop }
        @at_exit_setup = true
      end
    end
  end
end
