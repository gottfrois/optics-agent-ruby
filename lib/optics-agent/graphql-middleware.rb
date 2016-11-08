require 'optics-agent/instrumenters/field'

module OpticsAgent
  class GraphqlMiddleware
    def initialize(agent)
      @agent = agent
    end

    def call(*args)
      OpticsAgent::Instrumenters::Field.middleware(@agent, *args)
    end
  end
end
