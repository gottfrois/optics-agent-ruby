require 'optics-agent/reporting/schema'

module OpticsAgent::Reporting
  class SchemaJob
    def perform(agent)
      schema = OpticsAgent::Reporting::Schema.new agent.schema
      schema.send_with(agent)
    end
  end
end
