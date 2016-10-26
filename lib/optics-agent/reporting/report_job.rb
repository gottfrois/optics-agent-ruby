require 'optics-agent/reporting/report'

module OpticsAgent::Reporting
  class ReportJob
    def perform(agent)
      report = OpticsAgent::Reporting::Report.new
      agent.clear_query_queue.each do |item|
        report.add_query(*item)

        # XXX: don't send *every* trace
        query_trace = QueryTrace.new(*item)
        query_trace.send
      end

      report.decorate_from_schema(agent.schema)
      report.send
    end
  end
end
