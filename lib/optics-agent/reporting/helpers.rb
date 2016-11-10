require 'apollo/optics/proto/reports_pb'

module OpticsAgent::Reporting
  def generate_report_header
    # XXX: fill out
    Apollo::Optics::Proto::ReportHeader.new({
      agent_version: '0'
    })
  end

  def generate_timestamp(time)
    Apollo::Optics::Proto::Timestamp.new({
      seconds: time.to_i,
      nanos: time.to_i % 1 * 1e9
    });
  end

  def duration_nanos(start_time, end_time)
    throw "start_time before end_time" if (start_time > end_time)
    ((end_time - start_time) * 1e9).to_i
  end

  # XXX: implement
  def client_info(rack_env)
    {
      client_name: 'none',
      client_version: 'none',
      client_address: '::1'
    }
  end

  def add_latency(counts, start_time, end_time)
    counts[latency_bucket_for_times(start_time, end_time)] += 1
  end

  def latency_bucket_for_times(start_time, end_time)
    micros = (end_time - start_time) * 1e6
    latency_bucket(micros)
  end
end
