source ENV['GEM_SOURCE'] || "https://rubygems.org"

group :development, :unit_tests do
  gem "rake", "~> 10.0"
  gem 'rspec', '~> 2.0',                      :require => false
  gem 'rspec-puppet', '>= 2.1.0',             :require => false
  gem 'puppetlabs_spec_helper',               :require => false
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
  gem 'puppet', :require => false
end
