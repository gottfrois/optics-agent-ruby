require 'optics-agent/query_context'

module OpticsAgent
  module Instrumenters
    class Query
      attr_accessor :agent

      def before_query(query)
        return unless @agent
        query_context = query.context[:optics_agent]
        return if query_context == :skip

        @agent.ensure_reporting_stats!

        # the rack request didn't add the agent, maybe there is none?
        unless query_context
          @agent.warn """No agent passed in graphql context.
Ensure you set `context: { optics_agent: env[:optics_agent] }` when executing your graphql query (where `env` is the rack environment).
If you aren't using the rack middleware, `context: {optics_agent: :no_rack}` to avoid this warning.
If you don't want to instrument this query, pass `context: {optics_agent: :skip}`.
  """
          query_context = :no_rack
        end

        if query_context == :no_rack
          query.context[:optics_agent] = QueryContext.new(agent)
          query_context = query.context[:optics_agent]
        end

        query_context.with_document(query.query_string)
      end

      def after_query(query)
        return unless @agent
        query_context = query.context[:optics_agent]
        return if query_context == :skip

        agent.debug { "query_instrumenter: query completed" }
        query_context.query_finished!
      end
    end
  end
end
