require 'optics-agent/agent'
require 'optics-agent/reporting/query'

module OpticsAgent
  class RackMiddleware
    def initialize(app, options={})
      @app = app
    end

    def call(env)
      start_time = Time.now

      # XXX: figure out a way to pass this in here
      agent = OpticsAgent::Agent.instance
      agent.debug { "rack-middleware: request started" }
      query = OpticsAgent::Reporting::Query.new

      # Attach so resolver middleware can access
      env[:optics_agent] = RackAgent.new(agent, query)

      result = @app.call(env)

      # XXX: this approach means if the user forgets to call with_document
      # we just never log queries. Can we detect if the request is a graphql one?
      agent.debug { "rack-middleware: request finished" }
      if (query.document)
        agent.debug { "rack-middleware: adding query to agent" }
        agent.add_query(query, env, start_time, Time.now)
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
