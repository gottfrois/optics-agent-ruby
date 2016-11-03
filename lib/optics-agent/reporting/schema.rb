require 'json'
require 'graphql'

require 'apollo/optics/proto/reports_pb'
require 'optics-agent/reporting/helpers'
require 'optics-agent/instrumentation/query-schema'

module OpticsAgent::Reporting
  # A report for a whole schema
  class Schema
    include Apollo::Optics::Proto
    include OpticsAgent::Instrumentation
    include OpticsAgent::Reporting

    attr_accessor :message

    def initialize(schema)
      @message = SchemaReport.new({
        header: generate_report_header(),
        introspection_result: JSON.generate(introspect_schema(schema)),
        type: get_types(schema)
      })
    end

    # construct an array of Type (protobuf) objects
    def get_types(schema)
      types = []

      schema.types.keys.each do |type_name|
        next if type_name =~ /^__/
        type = schema.types[type_name]
        next unless type.is_a? GraphQL::ObjectType

        fields = type.fields.values.map do |field|
          Field.new({
            name: field.name,
            # XXX: does this actually work for all types?
            returnType: field.type.to_s
          })
        end

        types << Type.new({
          name: type_name,
          field: fields
        })
      end

      types
    end

    def send_with(agent)
      agent.send_message('/api/ss/schema', @message)
    end
  end
end
