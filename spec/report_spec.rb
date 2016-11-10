require 'optics-agent/reporting/report'
require 'optics-agent/reporting/query'
require 'apollo/optics/proto/reports_pb'
require 'graphql'

include OpticsAgent::Reporting
include Apollo::Optics::Proto

describe Report do
  it "can represent a simple query" do
    query = Query.new
    query.report_field 'Person', 'firstName', 1, 1.1
    query.report_field 'Person', 'lastName', 1, 1.1
    query.report_field 'Query', 'person', 1, 1.22
    query.document = '{field}'

    report = Report.new
    report.add_query query, {}, 1, 1.25
    report.finish!

    expect(report.report).to be_an_instance_of(StatsReport)
    stats_report = report.report
    expect(stats_report.per_signature.keys).to match_array(['{field}'])

    signature_stats = stats_report.per_signature.values.first
    expect(signature_stats.per_type.length).to equal(2)
    expect(signature_stats.per_type.map &:name).to match_array(['Person', 'Query'])

    person_stats = signature_stats.per_type.find { |s| s.name === 'Person' }
    expect(person_stats.field.length).to equal(2)
    expect(person_stats.field.map &:name).to match_array(['firstName', 'lastName'])

    firstName_stats = person_stats.field.find { |s| s.name === 'firstName' }
    expect(firstName_stats.latency_count.length).to eq(256)
    expect(firstName_stats.latency_count.reduce(&:+)).to eq(1)
    expect(firstName_stats.latency_count[121]).to eq(1)
  end

  it "can aggregate the results of multiple queries with the same shape" do
    queryOne = Query.new
    queryOne.report_field 'Person', 'firstName', 1, 1.1
    queryOne.report_field 'Person', 'lastName', 1, 1.1
    queryOne.report_field 'Query', 'person', 1, 1.22
    queryOne.document = '{field}'

    queryTwo = Query.new
    queryTwo.report_field 'Person', 'firstName', 1, 1.05
    queryTwo.report_field 'Person', 'lastName', 1, 1.05
    queryTwo.report_field 'Query', 'person', 1, 1.2
    queryTwo.document = '{field}'

    report = Report.new
    report.add_query queryOne, {}, 1, 1.1
    report.add_query queryTwo, {}, 1, 1.1
    report.finish!

    expect(report.report).to be_an_instance_of(StatsReport)
    stats_report = report.report
    expect(stats_report.per_signature.keys).to match_array(['{field}'])

    signature_stats = stats_report.per_signature.values.first
    expect(signature_stats.per_type.length).to equal(2)
    expect(signature_stats.per_type.map &:name).to match_array(['Person', 'Query'])

    person_stats = signature_stats.per_type.find { |s| s.name === 'Person' }
    expect(person_stats.field.length).to equal(2)
    expect(person_stats.field.map &:name).to match_array(['firstName', 'lastName'])

    firstName_stats = person_stats.field.find { |s| s.name === 'firstName' }
    expect(firstName_stats.latency_count.reduce(&:+)).to eq(2)
    expect(firstName_stats.latency_count[114]).to eq(1)
    expect(firstName_stats.latency_count[121]).to eq(1)
  end

  it "can aggregate the results of multiple queries with a different shape" do
    queryOne = Query.new
    queryOne.report_field 'Person', 'firstName', 1, 1.1
    queryOne.report_field 'Person', 'lastName', 1, 1.1
    queryOne.report_field 'Query', 'person', 1, 1.22
    queryOne.document = '{fieldOne}'

    queryTwo = Query.new
    queryTwo.report_field 'Person', 'firstName', 1, 1.05
    queryTwo.report_field 'Person', 'lastName', 1, 1.05
    queryTwo.report_field 'Query', 'person', 1, 1.02
    queryTwo.document = '{fieldTwo}'

    report = Report.new
    report.add_query queryOne, {}, 1, 1.1
    report.add_query queryTwo, {}, 1, 1.1
    report.finish!

    expect(report.report).to be_an_instance_of(StatsReport)
    stats_report = report.report
    expect(stats_report.per_signature.keys).to match_array(['{fieldOne}', '{fieldTwo}'])

    signature_stats = stats_report.per_signature['{fieldOne}']
    expect(signature_stats.per_type.length).to equal(2)
    expect(signature_stats.per_type.map &:name).to match_array(['Person', 'Query'])

    person_stats = signature_stats.per_type.find { |s| s.name === 'Person' }
    expect(person_stats.field.length).to equal(2)
    expect(person_stats.field.map &:name).to match_array(['firstName', 'lastName'])

    firstName_stats = person_stats.field.find { |s| s.name === 'firstName' }
    expect(firstName_stats.latency_count.reduce(&:+)).to eq(1)
    expect(firstName_stats.latency_count[121]).to eq(1)
  end


  it "can decorate it's fields with resultTypes from a schema" do
    query = Query.new
    query.report_field 'Person', 'firstName', 1, 1.1
    query.report_field 'Person', 'age', 1, 1.1
    query.document = '{field}'

    report = Report.new
    report.add_query query, {}, 1, 1.25
    report.finish!

    person_type = GraphQL::ObjectType.define do
      name 'Person'
      field :firstName, types.String
      field :age, !types.Int
    end
    query_type = GraphQL::ObjectType.define do
      name 'Query'
      field :person, person_type
    end

    schema = GraphQL::Schema.define do
      query query_type
    end

    report.decorate_from_schema(schema)

    stats_report = report.report
    signature_stats = stats_report.per_signature.values.first
    person_stats = signature_stats.per_type.find { |s| s.name === 'Person' }

    firstName_stats = person_stats.field.find { |s| s.name === 'firstName' }
    expect(firstName_stats.returnType).to eq('String')

    age_stats = person_stats.field.find { |s| s.name === 'age' }
    expect(age_stats.returnType).to eq('Int!')
  end

  it "can handle introspection fields" do
    query = Query.new
    query.report_field 'Query', '__schema', 1, 1.1
    query.report_field 'Query', '__typename', 1, 1.1
    query.report_field 'Query', '__type', 1, 1.1
    query.document = '{field}'

    report = Report.new
    report.add_query query, {}, 1, 1.25
    report.finish!

    query_type = GraphQL::ObjectType.define do
      name 'Query'
    end

    schema = GraphQL::Schema.define do
      query query_type
    end

    report.decorate_from_schema(schema)

    stats_report = report.report
    signature_stats = stats_report.per_signature.values.first
    query_stats = signature_stats.per_type.find { |s| s.name === 'Query' }

    schema_stats = query_stats.field.find { |s| s.name === '__schema' }
    expect(schema_stats.returnType).to eq('__Schema')

    type_stats = query_stats.field.find { |s| s.name === '__type' }
    expect(type_stats.returnType).to eq('__Type')

    typename_stats = query_stats.field.find { |s| s.name === '__typename' }
    expect(typename_stats.returnType).to eq('Query')
  end

  describe "trace reporting" do
      it "only sends one trace for two queries of the same shape and latency" do
        queryOne = Query.new
        queryOne.document = '{field}'

        queryTwo = Query.new
        queryTwo.document = '{field}'

        report = Report.new
        report.add_query queryOne, {}, 1, 1.1
        report.add_query queryTwo, {}, 1, 1.1
        report.finish!

        expect(report.traces_to_report.length).to be(1)
      end

      it "sends two traces for two queries of the same shape and different latencies" do
        queryOne = Query.new
        queryOne.document = '{field}'

        queryTwo = Query.new
        queryTwo.document = '{field}'

        report = Report.new
        report.add_query queryOne, {}, 1, 1.1
        report.add_query queryTwo, {}, 1, 1.2
        report.finish!

        expect(report.traces_to_report.length).to be(2)
      end

      it "sends two traces for two queries of different shapes and the same latency" do
        queryOne = Query.new
        queryOne.document = '{field}'

        queryTwo = Query.new
        queryTwo.document = '{field_two}'

        report = Report.new
        report.add_query queryOne, {}, 1, 1.1
        report.add_query queryTwo, {}, 1, 1.1
        report.finish!

        expect(report.traces_to_report.length).to be(2)
      end
  end
end
