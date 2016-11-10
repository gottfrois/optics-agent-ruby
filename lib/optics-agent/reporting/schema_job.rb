require 'optics-agent/reporting/schema'

module OpticsAgent::Reporting
  class SchemaJob
    def perform(agent)
      begin
        schema = OpticsAgent::Reporting::Schema.new agent.schema
        schema.send_with(agent)
      rescue StandardError => e
        agent.debug "schema report failed #{e}"
        agent.debug e.backtrace
        raise
      end
    end
  end
end
