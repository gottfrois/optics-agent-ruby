require 'optics-agent/reporting/query'

class QueryContext
  attr_reader :agent, :query, :no_rack
  def initialize(agent, rack_env = false)
    @agent = agent
    @query = OpticsAgent::Reporting::Query.new
    @rack_env = rack_env
  end

  def with_document(query_string)
    @query.document = query_string
    self
  end

  def query_finished!
    finish! unless @rack_env
  end

  def request_finished!
    finish!
  end

  private def finish!
    if (@query.document)
      @agent.debug { "query_context: Adding a query with #{@query.reports.length} field reports" }
      @query.finish!
      @agent.add_query(@query, @rack_env)
    end
  end
end
