module OpticsAgent
  module Instrumenters
    class Field
      attr_accessor :agent

      def instrument(type, field)
        old_resolve_proc = field.resolve_proc
        new_resolve_proc = ->(obj, args, ctx) {
          if @agent
            middleware(@agent, type, obj, field, args, ctx, ->() { old_resolve_proc.call(obj, args, ctx) })
          else
            old_resolve_proc.call(obj, args, ctx)
          end
        }

        new_field = field.redefine do
          resolve(new_resolve_proc)
        end

        new_field
      end

      def middleware(agent, parent_type, parent_object, field_definition, field_args, query_context, next_middleware)
        agent_context = query_context[:optics_agent]

        # This happens when an introspection query occurs (reporting schema)
        # Also, people could potentially use it to skip reporting
        return next_middleware.call if agent_context == :skip

        query = agent_context.query

        start_offset = query.duration_so_far
        result = next_middleware.call
        duration = query.duration_so_far - start_offset

        query.report_field(parent_type.to_s, field_definition.name, start_offset, duration)

        result
      end
    end
  end
end
