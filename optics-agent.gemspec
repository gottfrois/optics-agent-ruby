Gem::Specification.new do |s|
  s.name        = 'optics-agent'
  s.version     = '0.3.1'
  s.date        = '2016-10-06'
  s.summary     = "An Agent for Apollo Optics"
  s.description = "An Agent for Apollo Optics, http://optics.apollodata.com"
  s.authors     = ["Tom Coleman "]
  s.email       = 'tom@meteor.com'
  s.files       = Dir["{lib}/**/*", "LICENSE", "README.md"]
  s.test_files  = Dir["{spec}/**/*"]

  s.homepage    =
    'http://rubygems.org/gems/optics-agent'
  s.license     = 'MIT'

  s.add_runtime_dependency 'graphql', '~> 0.19.0'
  s.add_runtime_dependency 'google-protobuf', '~> 3.1.0'
  s.add_runtime_dependency 'faraday', '~> 0.9.2'
  s.add_runtime_dependency 'net-http-persistent', '~> 2.0.0'

  s.add_development_dependency 'rake', '~> 11.3.0'
  s.add_development_dependency 'rspec', '~> 3.5.0'
end
