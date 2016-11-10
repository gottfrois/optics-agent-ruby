require 'apollo/optics/proto/reports_pb'
require 'optics-agent/reporting/helpers'

module OpticsAgent::Reporting
  # A trace is just a different view of a single query report, with full
  # information about start and end times
  class QueryTrace
    include OpticsAgent::Reporting
    include Apollo::Optics::Proto

    attr_accessor :report

    def initialize(query, rack_env)
      trace = Trace.new({
        start_time: generate_timestamp(query.start_time),
        end_time: generate_timestamp(query.end_time),
        duration_ns: duration_nanos(query.duration),
        signature: query.signature
      })

      # XXX: report trace details (not totally clear yet from the JS agent what should be here)
      trace.details = Trace::Details.new({})

      info = client_info(rack_env)
      trace.client_name = info[:client_name]
      trace.client_version = info[:client_version]
      trace.client_address = info[:client_address]
      trace.http = Trace::HTTPInfo.new({
        host: "localhost:8080",
        path: "/graphql"
      })

      nodes = []
      query.each_report do |type_name, field_name, start_offset, duration|
        nodes << Trace::Node.new({
          field_name: "#{type_name}.#{field_name}",
          start_time: duration_nanos(start_offset),
          end_time: duration_nanos(start_offset + duration)
        })
      end
      trace.execute = Trace::Node.new({
        child: nodes
      })

      @report = TracesReport.new({
        header: generate_report_header,
        trace: [trace]
      })
    end

    def send_with(agent)
      agent.send_message('/api/ss/traces', @report)
    end
  end
end
