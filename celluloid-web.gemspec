# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'celluloid/dashboard/version'

Gem::Specification.new do |spec|
  spec.name          = 'celluloid-dashboard'
  spec.version       = Celluloid::Dashboard::VERSION
  spec.authors       = ['Tobias Bühlmann']
  spec.email         = ['tobias.buehlmann@gmx.de']
  spec.description   = %q{TODO: Write a gem description}
  spec.summary       = %q{TODO: Write a gem summary}
  spec.homepage      = 'https://github.com/tbuehlmann/celluloid-dashboard'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 1.9.2'

  spec.add_dependency 'celluloid'
  spec.add_dependency 'sinatra', '1.4.3'
  spec.add_dependency 'sinatra-contrib', '~> 1.4'
  spec.add_dependency 'sinatra-flash', '0.3'
  spec.add_dependency 'slim', '~> 2.0'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 2.14.0.rc1'
  spec.add_development_dependency 'pry', '~> 0.9'
end
