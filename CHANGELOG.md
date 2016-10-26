### vNEXT

### v0.2.1

- Use a simple `Thread.new` instead of sucker_punch and concurrent-ruby.

### v0.2.0

- We only require you to pass in the query_string, rather than the full graphql request params now. See https://github.com/apollostack/optics-agent-ruby/pull/27

### v0.1.3

- Wait until the schema is added to start the reporting loop. This means of pre-forking webservers like unicorn, we'll wait until the process has forked and started a "true" process.
