require 'optics-agent/rack-middleware'
require 'optics-agent/instrumenters/field'
require 'optics-agent/reporting/report_job'
require 'optics-agent/reporting/schema_job'
require 'optics-agent/reporting/query-trace'
require 'optics-agent/reporting/detect_server_side_error'
require 'net/http'
require 'faraday'
require 'logger'
require 'time'

module OpticsAgent
  class Agent
    include OpticsAgent::Reporting

    class << self
      attr_accessor :logger
    end

    self.logger = Logger.new(STDOUT)

    attr_reader :schema, :report_traces

    def initialize
      @stats_reporting_thread = nil
      @query_queue = []
      @semaphone = Mutex.new

      # set defaults
      @configuration = Configuration.new
    end

    def configure(&block)
      @configuration.instance_eval(&block)

      if @configuration.schema && @schema != @configuration.schema
        instrument_schema(@configuration.schema)
      end
    end

    def disabled?
      @configuration.disable_reporting || !@configuration.api_key || !@schema
    end

    def report_traces?
      @configuration.report_traces
    end

    def instrument_schema(schema)
      unless @configuration.api_key
        warn """No api_key set.
Either configure it or use the OPTICS_API_KEY environment variable.
"""
        return
      end

      if @schema
        warn """Agent has already instrumented a schema.
Perhaps you are calling both `agent.configure { schema YourSchema }` and
`agent.instrument_schema YourSchema`?
"""
        return
      end

      @schema = schema
      @schema._attach_optics_agent(self)

      unless disabled?
        debug "spawning schema thread"
        Thread.new do
          debug "schema thread spawned"
          sleep @configuration.schema_report_delay_ms / 1000.0
          debug "running schema job"
          SchemaJob.new.perform(self)
        end
      end
    end

    # We call this method on every request to ensure that the reporting thread
    # is active in the correct process for pre-forking webservers like unicorn
    def ensure_reporting_stats!
      unless @schema
        warn """No schema instrumented.
Use the `schema` configuration setting, or call `agent.instrument_schema`
"""
        return
      end

      unless reporting_stats? || disabled?
        schedule_report
      end
    end

    # @deprecated Use ensure_reporting_stats! instead
    def ensure_reporting!
      ensure_reporting_stats!
    end

    def reporting_connection
      @reporting_connection ||=
        Faraday.new(:url => @configuration.endpoint_url) do |conn|
          conn.request :retry,
                       :max => 5,
                       :interval => 0.1,
                       :max_interval => 10,
                       :backoff_factor => 2,
                       :exceptions => [Exception],
                       :retry_if => ->(env, exc) { true }
          conn.use OpticsAgent::Reporting::DetectServerSideError

          # XXX: allow setting adaptor in config
          conn.adapter :net_http_persistent
        end
    end

    def reporting_stats?
      @stats_reporting_thread != nil && !!@stats_reporting_thread.status
    end

    def schedule_report
      @semaphone.synchronize do
        return if reporting_stats?

        debug "spawning reporting thread"

        thread = Thread.new do
          begin
            debug "reporting thread spawned"

            report_interval = @configuration.report_interval_ms * 1000
            last_started = Time.now

            while true
              next_send = last_started + report_interval
              sleep_time = next_send - Time.now

              if sleep_time < 0
                warn 'Report took more than one interval! Some requests might appear at the wrong time.'
              else
                sleep sleep_time
              end

              debug "running reporting job"
              last_started = Time.now
              ReportJob.new.perform(self)
              debug "finished running reporting job"
            end
          rescue Exception => e
            warn "Stats report thread dying: #{e}"
          end
        end

        at_exit do
          if thread.status
            debug 'sending last stats report before exiting'
            thread.exit
            ReportJob.new.perform(self)
            debug 'last stats report sent'
          end
        end

        @stats_reporting_thread = thread
      end
    end

    def add_query(*args)
      @semaphone.synchronize {
        debug { "adding query to queue, queue length was #{@query_queue.length}" }
        @query_queue << args
      }
    end

    def clear_query_queue
      @semaphone.synchronize {
        debug { "clearing query queue, queue length was #{@query_queue.length}" }
        queue = @query_queue
        @query_queue = []
        queue
      }
    end

    def rack_middleware
      # We need to pass ourselves to the class we return here because
      # rack will instanciate it. (See comment at the top of RackMiddleware)
      OpticsAgent::RackMiddleware.agent = self
      OpticsAgent::RackMiddleware
    end

    def graphql_middleware
      warn "You no longer need to pass the optics agent middleware, it now attaches itself"
    end

    def send_message(path, message)
      response = reporting_connection.post do |request|
        request.url path
        request.headers['x-api-key'] = @configuration.api_key
        request.headers['user-agent'] = "optics-agent-rb"
        request.body = message.class.encode(message)

        if @configuration.debug || @configuration.print_reports
          log "sending message: #{message.class.encode_json(message)}"
        end
      end

      if @configuration.debug || @configuration.print_reports
        log "got response body: #{response.body}"
      end
    end

    def log(message = nil)
      message = yield unless message
      self.class.logger.info "optics-agent: #{message}"
    end

    def warn(message = nil)
      self.class.logger.warn "optics-agent: WARNING: #{message}"
    end

    # Should we be using built in debug levels rather than our own "debug" flag?
    def debug(message = nil)
      if @configuration.debug
        message = yield unless message
        self.class.logger.info "optics-agent: DEBUG: #{message} <#{Process.pid} | #{Thread.current.object_id}>"
      end
    end
  end

  class Configuration
    def self.defaults
      {
        schema: nil,
        debug: false,
        disable_reporting: false,
        print_reports: false,
        report_traces: true,
        schema_report_delay_ms: 10 * 1000,
        report_interval_ms: 60 * 1000,
        api_key: ENV['OPTICS_API_KEY'],
        endpoint_url: ENV['OPTICS_ENDPOINT_URL'] || 'https://optics-report.apollodata.com'
      }
    end

    # Allow e.g. `debug false` == `debug = false` in configuration blocks
    defaults.each_key do |key|
      define_method key, ->(*maybe_value) do
        if (maybe_value.length === 1)
          self.instance_variable_set("@#{key}", maybe_value[0])
        elsif (maybe_value.length === 0)
          self.instance_variable_get("@#{key}")
        else
          throw new ArgumentError("0 or 1 argument expected")
        end
      end
    end

    def initialize
      self.class.defaults.each { |key, value| self.send(key, value) }
    end
  end
end
