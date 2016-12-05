require 'ostruct'
require 'optics-agent/instrumenters/field'
require 'graphql'

include OpticsAgent

describe Instrumenters::Field do
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

    instrumenter = Instrumenters::Field.new(true)
    schema = GraphQL::Schema.define do
      query query_type
      instrument :field, instrumenter
    end

    query = spy("query")
    allow(query).to receive(:duration_so_far).and_return(1.0)

    schema.execute('{ person { firstName lastName } }', {
      context: { optics_agent: OpenStruct.new(query: query) }
    })

    expect(query).to have_received(:report_field).exactly(3).times
    expect(query).to have_received(:report_field)
      .with('Query', 'person', be_instance_of(Float), be_instance_of(Float))
    expect(query).to have_received(:report_field)
      .with('Person', 'firstName', be_instance_of(Float), be_instance_of(Float))
    expect(query).to have_received(:report_field)
      .with('Person', 'lastName', be_instance_of(Float), be_instance_of(Float))
  end
end
