module OpticsAgent
  module Instrumentation
    INTROSPECTION_QUERY ||= IO.read("#{File.dirname(__FILE__)}/introspection-query.graphql")

    def introspect_schema(schema)
      result = schema.execute(INTROSPECTION_QUERY,
        context: {optics_agent: :skip}
      )

      result['data']['__schema']
    end
  end
end
