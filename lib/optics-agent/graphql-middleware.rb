module OpticsAgent
  class GraphqlMiddleware
    def call(parent_type, parent_object, field_definition, field_args, query_context, next_middleware)
      # This happens when an introspection query occurs (reporting schema)
      # However, we could also use it to tell people if they've set things up wrong.
      return next_middleware.call unless query_context[:optics_agent]

      query = query_context[:optics_agent].query

      start_offset = query.duration_so_far
      result = next_middleware.call
      duration = query.duration_so_far - start_offset

      query = query_context[:optics_agent].query
      query.report_field(parent_type.to_s, field_definition.name, start_offset, duration)

      result
    end
  end
end
