require 'optics-agent/reporting/report'

module OpticsAgent::Reporting
  class ReportJob
    def perform(agent)
      begin
        report = OpticsAgent::Reporting::Report.new(report_traces: agent.report_traces?)
        agent.clear_query_queue.each do |item|
          report.add_query(*item)
        end

        report.decorate_from_schema(agent.schema)
        report.send_with(agent)
      rescue Exception => e
        agent.debug "stats report failed #{e}"
        agent.debug e.backtrace
      end
    end
  end
end
