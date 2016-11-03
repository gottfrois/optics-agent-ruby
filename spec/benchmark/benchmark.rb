# Run with ruby -Ilib spec/benchmark/benchmark.rb

require 'benchmark'
require 'graphql'
require 'optics-agent'

require_relative '../support/create_starwars_schema.rb';

basic_schema = create_starwars_schema

agent = OpticsAgent::Agent.instance
agent.set_options(disable_reporting: true)
instrumented_schema = create_starwars_schema
agent.instrument_schema(instrumented_schema)

# just drop reports on the floor
class BenchmarkRackAgent
  class Query
    def report_field(x,y,z,w)
    end
  end

  attr_reader :query
  def initialize
    @query = Query.new
  end
end
rack_agent = BenchmarkRackAgent.new

query_string = GraphQL::Introspection::INTROSPECTION_QUERY

Benchmark.bmbm(4) do |x|
  x.report("No agent") do
    1000.times do
      basic_schema.execute(query_string)
    end
  end
  x.report("With agent") do
    1000.times do
      instrumented_schema.execute(query_string, context: {
        optics_agent: rack_agent
      })
    end
  end
end
