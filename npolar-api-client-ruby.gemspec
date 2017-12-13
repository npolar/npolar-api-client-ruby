# encoding: utf-8
# https://github.com/radar/guides/blob/master/gem-development.md
# require File.expand_path(File.dirname(__FILE__)+"/lib/npolar/api/client")

lib = File.expand_path('../lib/', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |s|
  s.name        = "npolar-api-client-ruby"
  s.version     = "0.3.10"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Conrad Helgeland"]
  s.email       = ["data*npolar.no"]
  s.homepage    = "http://github.com/npolar/npolar-api-client-ruby"
  s.summary     = "Ruby client library and command line tools for https://api.npolar.no"
  s.description = "Official Ruby client for the Norwegian Polar Institute's API."
  s.license       = 'GPL-3.0'

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "bundler"
  s.add_development_dependency "rspec"
  s.add_development_dependency "thin"
  s.add_development_dependency "shotgun"
  s.add_development_dependency "simplecov"
  s.add_development_dependency "ruby-prof"

  s.add_runtime_dependency "hashie"    , "3.4.6"
  s.add_runtime_dependency "typhoeus"  , "1.1.2"
  s.add_runtime_dependency "yajl-ruby" , "1.3.1"
  s.add_runtime_dependency "uuidtools" , "2.1.5"
end
