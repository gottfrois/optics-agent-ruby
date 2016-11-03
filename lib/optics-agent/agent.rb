require 'singleton'
require 'optics-agent/rack-middleware'
require 'optics-agent/graphql-middleware'
require 'optics-agent/reporting/report_job'
require 'optics-agent/reporting/schema_job'
require 'optics-agent/reporting/query-trace'
require 'net/http'

module OpticsAgent
  # XXX: this is a class but acts as a singleton right now.
  # Need to figure out how to pass the agent into the middleware
  #   (for instance we could dynamically generate a middleware class,
  #    or ask the user to pass the agent as an option) to avoid it
  class Agent
    include Singleton
    include OpticsAgent::Reporting

    attr_reader :schema

    def initialize
      @query_queue = []
      @semaphone = Mutex.new

      # set defaults
      self.set_options
    end

    def set_options(
      debug: false,
      disable_reporting: false,
      print_reports: false,
      schema_report_delay_ms: 10 * 1000,
      report_interval_ms: 60 * 1000,
      api_key: ENV['OPTICS_API_KEY'],
      endpoint_url: ENV['OPTICS_ENDPOINT_URL'] || 'https://optics-report.apollodata.com'
    )
      @debug = debug
      @disable_reporting = disable_reporting || !endpoint_url || endpoint_url.nil?
      @print_reports = print_reports
      @schema_report_delay_ms = schema_report_delay_ms
      @report_interval_ms = report_interval_ms
      @api_key = api_key
      @endpoint_url = endpoint_url
    end

    def instrument_schema(schema)
      @schema = schema
      debug "adding middleware to schema"
      schema.middleware << graphql_middleware

      unless @disable_reporting
        debug "spawning schema thread"
        Thread.new do
          debug "schema thread spawned"
          sleep @schema_report_delay_ms / 1000
          debug "running schema job"
          SchemaJob.new.perform(self)
        end

        schedule_report
      end
    end

    def schedule_report
      debug "spawning reporting thread"
      Thread.new do
        debug "reporting thread spawned"
        while true
          sleep @report_interval_ms / 1000
          debug "running reporting job"
          ReportJob.new.perform(self)
        end
      end
    end

    def add_query(query, rack_env, start_time, end_time)
      @semaphone.synchronize {
        debug { "adding query to queue, queue length was #{@query_queue.length}" }
        @query_queue << [query, rack_env, start_time, end_time]
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
      OpticsAgent::RackMiddleware
    end

    def graphql_middleware
      # graphql middleware doesn't seem to need the agent but certainly could have it
      OpticsAgent::GraphqlMiddleware.new
    end

    def send_message(path, message)
      req = Net::HTTP::Post.new(path)
      req['x-api-key'] = @api_key
      req['user-agent'] = "optics-agent-rb"

      req.body = message.class.encode(message)
      if @debug || @print_reports
        log "sending message: #{message.class.encode_json(message)}"
      end

      uri = URI.parse(@endpoint_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      res = http.request(req)

      if @debug || @print_reports
        log "got response: #{res.inspect}"
        log "response body: #{res.body.inspect}"
      end
    end

    def log(message = nil)
      message = yield unless message
      puts "optics-agent: #{message}"
    end

    def debug(message = nil)
      if @debug
        message = yield unless message
        log "DEBUG: #{message} <#{Process.pid} | #{Thread.current.object_id}>"
      end
    end
  end
end
