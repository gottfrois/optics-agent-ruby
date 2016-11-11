# optics-agent-ruby
Optics Agent for GraphQL Monitoring in Ruby.

This is an alpha release, suitable for use in development contexts. There are still some outstanding improvements to make it ready for production contexts; see the [known limitations](#known-limitations) section below.

[![Gem Version](https://badge.fury.io/rb/optics-agent.svg)](https://badge.fury.io/rb/optics-agent) [![Build Status](https://travis-ci.org/apollostack/optics-agent-ruby.svg?branch=master)](https://travis-ci.org/apollostack/optics-agent-ruby)


## Installing

Add

```ruby
gem 'optics-agent'
```

To your `Gemfile`

## Setup

### API key

You'll need to run your app with the `OPTICS_API_KEY` environment variable set (or set via options) to the API key of your Apollo Optics service; you can get an API key by setting up a service at https://optics.apollodata.com.

### Configuration

After creating an agent (see below), you can configure it with

```rb
agent.configure do
  key value
end
```

Possible keys are:

  - `schema` - The schema you wish to instrument
  - `api_key` - Your API key for the Optics service. This defaults to the OPTICS_API_KEY environment variable, but can be overridden here.
  - `endpoint_url ['https://optics-report.apollodata.com']` - Where to send the reports. Defaults to the production Optics endpoint, or the `OPTICS_ENDPOINT_URL` environment variable if it is set. You shouldn't need to set this unless you are debugging
  - `debug [false]` - Log detailed debugging messages
  - `disable_reporting [false]` - Don't report anything to Optics (useful for testing)
  - `print_reports [false]` - Print JSON versions of the data sent to Optics to the log
  - `report_traces [true]` - Send detailed traces along with usage reports
  - `schema_report_delay_ms [10000]` - How long to wait before sending a schema report after startup, in, milliseconds
  - `report_interval_ms [60000]` - How often to send reports in milliseconds. Defaults to 1 minute. Minimum 10 seconds. You shouldn't need to set this unless you are debugging.

### Basic Rack/Sinatra

Create an agent

```ruby
agent = OpticsAgent::Agent.new
# see above for configuration options
agent.configure do
  schema MySchema
end
```

Register the Rack middleware (say in a `config.ru`):

```ruby
use agent.rack_middleware
```

Add something like this to your route:

```ruby
post '/graphql' do
  request.body.rewind
  params = JSON.parse request.body.read
  document = params['query']
  variables = params['variables']

  result = Schema.execute(
    document,
    variables: variables,
    context: { optics_agent: env[:optics_agent].with_document(document) }
  )

  JSON.generate(result)
end
```

## Rails

The equivalent of the above for Rails is:

Create an agent in `config/application.rb`, and register the rack middleware:

```ruby
module YourApplicationRails
  class Application < Rails::Application
    # ...

    config.optics_agent = OpticsAgent::Agent.new
    # see above for configuration options
    config.optics_agent.configure do
      schema MySchema
    end

    config.middleware.use config.optics_agent.rack_middleware
  end
end

```

Register Optics Agent on the GraphQL context within your `graphql` action as below:

```ruby
def create
  query_string = params[:query]
  query_variables = ensure_hash(params[:variables])

  result = YourSchema.execute(
    query_string,
    variables: query_variables,
    context: {
      optics_agent: env[:optics_agent].with_document(query_string)
    }
  )

  render json: result
end
```

You can check out the GitHunt Rails API server example here: https://github.com/apollostack/githunt-api-rails

## Known limitations

Currently the agent is in alpha state; it is intended for early access use in development or basic (non-performance oriented) staging testing.

We are working on resolving a [list of issues](https://github.com/apollostack/optics-agent-ruby/projects/1) to put together a production-ready beta launch. The headline issues as things stand are:

- The agent is overly chatty and uses a naive threading mechanism that may lose reporting data when threads exit/etc.
- Instrumentation timings may not be correct in all uses cases, and query times include the full rack request time.

You can follow along with our [Beta Release Project](https://github.com/apollostack/optics-agent-ruby/projects/1), or even get in touch if you want to help out getting there!

## Development

### Running tests

```
bundle install
bundle exec rspec
```

### Building protobuf definitions

Ensure you've installed `protobuf` and development dependencies.

```bash
# this works on OSX
brew install protobuf

# ensure it's version 3
protoc --version

bundle install
````

Compile the `.proto` definitions with

```bash
bundle exec rake protobuf:compile
```
