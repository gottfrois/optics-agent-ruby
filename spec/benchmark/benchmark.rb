require 'benchmark'
require 'graphql'
require 'optics-agent'

require_relative '../support/create_starwars_schema.rb';

basic_schema = create_starwars_schema

agent = OpticsAgent::Agent.instance
instrumented_schema = create_starwars_schema
agent.instrument_schema(instrumented_schema)

# just drop reports on the floor
null_reporter = {}
null_reporter.define_singleton_method :report_field, lambda { |x,y,z,w| }

query_string = GraphQL::Introspection::INTROSPECTION_QUERY

Benchmark.bm(7) do |x|
  x.report("No agent") do
    20.times do
      basic_schema.execute(query_string)
    end
  end
  x.report("With agent") do
    20.times do
      instrumented_schema.execute(query_string, context: {
        optics_agent: { query: null_reporter }
      })
    end
  end
end
