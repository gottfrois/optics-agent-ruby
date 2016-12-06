require 'apollo/optics/proto/reports_pb'

module OpticsAgent::Reporting
  def generate_report_header
    # XXX: fill out
    Apollo::Optics::Proto::ReportHeader.new({
      agent_version: "optics-agent-ruby #{OpticsAgent::VERSION}"
    })
  end

  def generate_timestamp(time)
    Apollo::Optics::Proto::Timestamp.new({
      seconds: time.to_i,
      nanos: duration_nanos(time.to_f % 1)
    });
  end

  def duration_nanos(duration_in_seconds)
    (duration_in_seconds * 1e9).to_i
  end

  def duration_micros(duration_in_seconds)
    (duration_in_seconds * 1e6).to_i
  end

  # XXX: implement
  def client_info(rack_env)
    {
      client_name: 'none',
      client_version: 'none',
      client_address: '::1'
    }
  end

  def add_latency(counts, duration_in_seconds)
    counts[latency_bucket_for_duration(duration_in_seconds)] += 1
  end

  def latency_bucket_for_duration(duration_in_seconds)
    latency_bucket(duration_micros(duration_in_seconds))
  end
end
