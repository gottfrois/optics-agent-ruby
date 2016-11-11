module OpticsAgent
  class GraphqlMiddleware
    def initialize(agent)
      @agent = agent
    end

    def call(parent_type, parent_object, field_definition, field_args, query_context, next_middleware)
      agent_context = query_context[:optics_agent]

      unless agent_context
        @agent.warn """No agent passed in graphql context.
Ensure you set `context: {optics_agent: env[:optics_agent].with_document(document) }``
when executing your graphql query.
If you don't want to instrument this query, pass `context: {optics_agent: :skip}`.
"""
        return
      end

      # This happens when an introspection query occurs (reporting schema)
      # Also, people could potentially use it to skip reporting
      if agent_context == :skip
        return next_middleware.call
      end

      query = agent_context.query

      start_offset = query.duration_so_far
      result = next_middleware.call
      duration = query.duration_so_far - start_offset

      query.report_field(parent_type.to_s, field_definition.name, start_offset, duration)

      result
    end
  end
end
