require 'ostruct'
require 'optics-agent/graphql-middleware'
require 'graphql'

include OpticsAgent

describe GraphqlMiddleware do
  it 'collects the correct query stats' do
    person_type = GraphQL::ObjectType.define do
      name "Person"
      field :firstName do
        type types.String
        resolve -> (obj, args, ctx) { sleep(0.100); return 'Tom' }
      end
      field :lastName do
        type types.String
        resolve -> (obj, args, ctx) { sleep(0.100); return 'Coleman' }
      end
    end
    query_type = GraphQL::ObjectType.define do
      name 'Query'
      field :person do
        type person_type
        resolve -> (obj, args, ctx) { sleep(0.050); return {} }
      end
    end

    schema = GraphQL::Schema.define do
      query query_type
    end

    schema.middleware << GraphqlMiddleware.new

    query = spy("query")
    schema.execute('{ person { firstName lastName } }', {
      context: { optics_agent: OpenStruct.new(query: query) }
    })

    expect(query).to have_received(:report_field).exactly(3).times
    expect(query).to have_received(:report_field)
      .with('Query', 'person', be_instance_of(Time), be_instance_of(Time))
    expect(query).to have_received(:report_field)
      .with('Person', 'firstName', be_instance_of(Time), be_instance_of(Time))
    expect(query).to have_received(:report_field)
      .with('Person', 'lastName', be_instance_of(Time), be_instance_of(Time))
  end
end
