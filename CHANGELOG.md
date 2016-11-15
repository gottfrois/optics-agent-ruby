### vNEXT

### v0.4.2
- Loosened unnecessarily strict dependencies in gemspec


### v0.4.1
- Fix issue where queries did not execute if you mis-configured the agent (now it just warns).

- Use the Rails logger if available and allow setting `OpticsAgent::Agent.logger`.

### v0.4.0

#### Breaking

- Requires `graphl-ruby@1.1.0`

- We have a new configuration setup, read it [here](https://github.com/apollostack/optics-agent-ruby#rails-setup)

  - Use `OpticsAgent::Agent.new` rather than `OpticsAgent::Agent.instance`

  - Use `agent.configure`, with a [DSL](https://github.com/apollostack/optics-agent-ruby#configuration) rather than `agent.set_options`

#### New features

- Sample the traces we report [Issue #20](https://github.com/apollostack/optics-agent-ruby/issues/20), rather than reporting a trace for every query.

- Use `hitimes`, a high resolution timer library [Issue #21](https://github.com/apollostack/optics-agent-ruby/issues/21).

- You can now disable trace reporting with the `report_traces` option

### v0.3.1

- Be more aggressive about waiting until the first request to spawn the reporting thread; to achieve better behaviour on pre-forking webservers such as Unicorn and Puma.


### v0.3.0

- Added `agent.set_options` to allow you to configure the agent. (See the README for more info)
- Added a `debug` option which logs a lot of useful info about reporting
- Use an object for :optics_agent [PR #28](https://github.com/apollostack/optics-agent-ruby/pull/28)

### v0.2.1

- Use a simple `Thread.new` instead of sucker_punch and concurrent-ruby.

### v0.2.0

- We only require you to pass in the query_string, rather than the full graphql request params now. See https://github.com/apollostack/optics-agent-ruby/pull/27

### v0.1.3

- Wait until the schema is added to start the reporting loop. This means of pre-forking webservers like unicorn, we'll wait until the process has forked and started a "true" process.
