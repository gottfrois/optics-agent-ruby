# Monkey patch GraphQL::Schema.define so that it automatically attaches our
# field instrumenter. Our instrumenter will do nothing unless we later attach
# an agent to it, which this will also allow us to do.

require 'graphql'
require 'optics-agent/instrumenters/field'

module OpticsAgent::GraphQLSchemaExtensions
  def define(**kwargs, &block)
    @instrumenter = OpticsAgent::Instrumenters::Field.new

    class << self
      def _attach_optics_agent(agent)
        agent.debug "Attaching agent to field instrumenter"
        @instrumenter.agent = agent
      end
    end

    instrumenter = @instrumenter
    super **kwargs do
      instance_eval(&block)
      instrument :field, instrumenter
    end
  end
end

class GraphQL::Schema
  prepend OpticsAgent::GraphQLSchemaExtensions
end
