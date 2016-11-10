require 'optics-agent/reporting/report'

module OpticsAgent::Reporting
  class ReportJob
    def perform(agent)
      begin
        report = OpticsAgent::Reporting::Report.new
        agent.clear_query_queue.each do |item|
          report.add_query(*item)
        end

        report.decorate_from_schema(agent.schema)
        report.send_with(agent)
      rescue StandardError => e
        agent.debug "report failed #{e}"
        raise
      end
    end
  end
end
