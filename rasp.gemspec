# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "rasp/version"

Gem::Specification.new do |s|
  s.name        = "rasp"
  s.version     = Rasp::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Matthew Draper"]
  s.email       = ["matthew@trebex.net"]
  s.homepage    = ""
  s.summary     = %q{A VBScript runtime. Just because.}
  s.description = %q{A VBScript runtime. Just because. I really hope no-one is in the unfortunate position of having a use for it.}

  s.add_dependency "citrus", "~> 2.2.2"

  s.add_development_dependency "rspec", "~> 2.1.0"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
