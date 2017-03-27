require 'optics-agent/query_context'

module OpticsAgent
  class RackMiddleware
    # Right now we assume there'll only be a single rack middleware in an
    # app, and set the agent via a class attribute. This means that in theory
    # you could use more than one agent, but at most one middleware.
    # In the future, if we see a need for more than one middleware, we could
    # probably just copy the class when calling `agent.rack_middleware`
    class << self
      attr_accessor :agent
    end

    def initialize(app, options={})
      @app = app
    end

    def call(env)
      agent = self.class.agent
      agent.ensure_reporting_stats!
      agent.debug { "rack-middleware: request started" }

      # Attach so field instrumenters can access
      env[:optics_agent] = QueryContext.new(agent, env)

      result = @app.call(env)

      agent.debug { "rack-middleware: request finished" }
      query = env[:optics_agent].request_finished!

      result
    end
  end
end
