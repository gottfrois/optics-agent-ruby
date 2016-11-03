### vNEXT

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
