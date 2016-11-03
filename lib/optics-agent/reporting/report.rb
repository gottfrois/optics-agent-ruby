require 'apollo/optics/proto/reports_pb'
require 'optics-agent/reporting/helpers'
require 'optics-agent/normalization/latency'

module OpticsAgent::Reporting
  # This class represents a complete report that we send to the optics server
  # It pretty closely wraps the StatsReport protobuf message with a few
  # convenience methods
  class Report
    include Apollo::Optics::Proto
    include OpticsAgent::Reporting
    include OpticsAgent::Normalization

    attr_accessor :report

    def initialize
      # internal report that we encapsulate
      @report = StatsReport.new({
        header: ReportHeader.new({
          agent_version: '1'
        }),
        start_time: generate_timestamp(Time.now)
      })
    end

    def finish!
      @report.end_time ||= generate_timestamp(Time.now)
      @report.realtime_duration || duration_nanos(@report.start_time, @report.end_time)
    end

    def send_with(agent)
      self.finish!
      agent.send_message('/api/ss/stats', @report)
    end

    # XXX: record timing / client
    def add_query(query, rack_env, start_time, end_time)
      @report.per_signature[query.signature] ||= StatsPerSignature.new
      signature_stats = @report.per_signature[query.signature]

      add_client_stats(signature_stats, rack_env, start_time, end_time)
      query.add_to_stats(signature_stats)
    end

    def add_client_stats(signature_stats, rack_env, start_time, end_time)
      info = client_info(rack_env)
      signature_stats.per_client_name[info[:client_name]] ||= StatsPerClientName.new({
        latency_count: empty_latency_count,
        error_count: empty_latency_count
      })
      client_stats = signature_stats.per_client_name[info[:client_name]]

      # XXX: handle errors
      add_latency(client_stats.latency_count, start_time, end_time)

      client_stats.count_per_version[info[:client_version]] ||= 0
      client_stats.count_per_version[info[:client_version]] += 1
    end

    # take a graphql schema and add returnTypes to all the fields on our report
    def decorate_from_schema(schema)
      each_field do |type_stat, field_stat|
        # short circuit for special fields
        field_stat.returnType = type_stat.name if field_stat.name == '__typename'

        if type_stat.name == 'Query'
          field_stat.returnType = '__Type' if field_stat.name == '__type'
          field_stat.returnType = '__Schema' if field_stat.name == '__schema'
        end

        if field_stat.returnType.empty?
          type = schema.types[type_stat.name]
          throw "Type #{type_stat.name} not found!" unless type

          field = type.fields[field_stat.name]
          throw "Field #{type_stat.name}.#{field_stat.name} not found!" unless field

          field_stat.returnType = field.type.to_s
        end
      end
    end

    # do something once per field we've collected
    def each_field
      @report.per_signature.values.each do |sps|
        sps.per_type.each do |type|
          type.field.each do |field|
            yield type, field
          end
        end
      end
    end
  end
end
