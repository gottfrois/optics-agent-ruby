module OpticsAgent
end

require 'optics-agent/agent'
require 'optics-agent/instrumenters/patch-graphql-schema'

require 'optics-agent/railtie' if defined?(Rails)
