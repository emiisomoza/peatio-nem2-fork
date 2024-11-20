
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "peatio/nem2/version"

Gem::Specification.new do |spec|
  spec.name          = "peatio-nem2"
  spec.version       = Peatio::Nem2::VERSION
  spec.authors       = ["Emiliano"]
  spec.email         = ["emi@rewards4earth.com"]

  spec.summary       = %q{Peatio Blockchain Plugin}
  spec.description   = %q{Peatio Blockchain Plugin to use the nem network with peatio}
  spec.homepage      = "https://www.erthexchange.com.au"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  #if spec.respond_to?(:metadata)
  #  spec.metadata["allowed_push_host"] = 'http://rubygems.org'
  #
  #  spec.metadata["homepage_uri"] = spec.homepage
  #  spec.metadata["source_code_uri"] = "https://git.rewards4earth.com/rewards4earth/peatio-nem2"
  #else
  #  raise "RubyGems 2.0 or newer is required to protect against " \
  #    "public gem pushes."
  #end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir['lib/**/*.rb']
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "webmock", "~> 3.5"
  spec.add_development_dependency "mocha", "~> 1.8"

  spec.add_dependency "activesupport", "~> 5.2.3"
  spec.add_dependency "better-faraday", "~> 1.0.5"
  spec.add_dependency "faraday", "~> 0.17"
  spec.add_dependency "memoist", "~> 0.16.0"
  spec.add_dependency "peatio", ">= 0.6.3"
  spec.add_dependency 'net-http-persistent', '~> 3.0.1'
  spec.add_dependency "nem-ruby", "~> 0.0.13"
end
