source ENV['GEM_SOURCE'] || "https://rubygems.org"

group :development, :unit_tests do
  gem "rake", "< 11.0"
  gem 'rspec'
  gem 'rspec-puppet'
  gem 'puppetlabs_spec_helper'
  gem 'puppet_facts',                         :require => false
  gem 'json_pure', '2.0.1'
end

if facterversion = ENV['FACTER_GEM_VERSION']
  gem 'facter', facterversion, :require => false
else
  gem 'facter', :require => false
end

if puppetversion = ENV['PUPPET_GEM_VERSION']
  gem 'puppet', puppetversion, :require => false
else
  gem 'puppet', "5.3.3"
end
