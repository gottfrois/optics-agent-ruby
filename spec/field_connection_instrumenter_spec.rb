require 'ostruct'
require 'optics-agent/instrumenters/field'
require 'graphql'

include OpticsAgent

describe "connection" do
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
      connection :people do
        type person_type.connection_type
        resolve -> (obj, args, ctx) { ["a", "b", "c"] }
      end
    end

    instrumenter = Instrumenters::Field.new
    instrumenter.agent = true
    schema = GraphQL::Schema.define do
      query query_type
      instrument :field, instrumenter
    end

    query = spy("query")
    allow(query).to receive(:duration_so_far).and_return(1.0)

    result = schema.execute('{ people(first: 2) { edges { node { firstName lastName } } } }', {
      context: { optics_agent: OpenStruct.new(query: query) }
    })

    expect(result).not_to have_key("errors")
    expect(result).to have_key("data")

    expect(query).to have_received(:report_field).exactly(1 + 1 + 2 * 1 + 2 * 2).times
    expect(query).to have_received(:report_field)
      .with('Query', 'people', be_instance_of(Float), be_instance_of(Float))
    expect(query).to have_received(:report_field)
      .exactly(2).times
      .with('Person', 'firstName', be_instance_of(Float), be_instance_of(Float))
    expect(query).to have_received(:report_field)
      .exactly(2).times
      .with('Person', 'lastName', be_instance_of(Float), be_instance_of(Float))
  end
end
