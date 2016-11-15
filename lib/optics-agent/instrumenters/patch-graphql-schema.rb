# Monkey patch GraphQL::Schema.define so that it automatically attaches our
# field instrumenter. Our instrumenter will do nothing unless we later attach
# an agent to it, which this will also allow us to do.

require 'graphql'
require 'optics-agent/instrumenters/field'
require 'optics-agent/instrumenters/query'

module OpticsAgent::GraphQLSchemaExtensions
  def define(**kwargs, &block)
    @field_instrumenter = OpticsAgent::Instrumenters::Field.new
    @query_instrumenter = OpticsAgent::Instrumenters::Query.new

    class << self
      def _attach_optics_agent(agent)
        agent.debug "Attaching agent to instrumenters"
        @field_instrumenter.agent = @query_instrumenter.agent = agent
      end
    end

    field_instrumenter = @field_instrumenter
    query_instrumenter = @query_instrumenter
    super **kwargs do
      instance_eval(&block) if block
      instrument :field, field_instrumenter
      instrument :query, query_instrumenter
    end
  end
end

class GraphQL::Schema
  prepend OpticsAgent::GraphQLSchemaExtensions
end
