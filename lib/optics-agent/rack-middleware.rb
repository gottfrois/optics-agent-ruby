require 'optics-agent/agent'
require 'optics-agent/reporting/query'
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
      agent.ensure_reporting!
      agent.debug { "rack-middleware: request started" }

      query = OpticsAgent::Reporting::Query.new

      # Attach so resolver middleware can access
      env[:optics_agent] = RackAgent.new(agent, query)

      result = @app.call(env)

      agent.debug { "rack-middleware: request finished" }
      if (query.document)
        agent.debug { "rack-middleware: Adding a query with #{query.reports.length} field reports" }
        query.finish!
        agent.add_query(query, env)
      end

      result
    end
  end

  class RackAgent
    attr_reader :agent, :query
    def initialize(agent, query)
      @agent = agent
      @query = query
    end

    def with_document(query_string)
      @query.document = query_string
      self
    end
  end
end
