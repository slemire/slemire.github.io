# -*- encoding: utf-8 -*-
# stub: jekyll-manager 0.1.1 ruby lib

Gem::Specification.new do |s|
  s.name = "jekyll-manager".freeze
  s.version = "0.1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "allowed_push_host" => "https://rubygems.org" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Ashwin Maroli".freeze]
  s.bindir = "exe".freeze
  s.date = "2017-07-24"
  s.description = "An administrative framework for Jekyll sites, Jekyll Manager is essentially Jekyll Admin repackaged with some alterations.".freeze
  s.email = ["ashmaroli@gmail.com".freeze]
  s.homepage = "https://github.com/ashmaroli/jekyll-manager".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.3.5".freeze
  s.summary = "Jekyll Admin repackaged with some alterations".freeze

  s.installed_by_version = "3.3.5" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<jekyll>.freeze, ["~> 3.5"])
    s.add_runtime_dependency(%q<sinatra>.freeze, ["~> 1.4"])
    s.add_runtime_dependency(%q<sinatra-contrib>.freeze, ["~> 1.4"])
    s.add_runtime_dependency(%q<addressable>.freeze, ["~> 2.4"])
    s.add_runtime_dependency(%q<oj>.freeze, ["~> 3.3", ">= 3.3.2"])
    s.add_development_dependency(%q<bundler>.freeze, ["~> 1.7"])
    s.add_development_dependency(%q<rake>.freeze, ["~> 10.0"])
    s.add_development_dependency(%q<rspec>.freeze, ["~> 3.4"])
    s.add_development_dependency(%q<rubocop>.freeze, ["~> 0.48.1"])
    s.add_development_dependency(%q<sinatra-cross_origin>.freeze, ["~> 0.3"])
    s.add_development_dependency(%q<gem-release>.freeze, ["~> 0.7"])
  else
    s.add_dependency(%q<jekyll>.freeze, ["~> 3.5"])
    s.add_dependency(%q<sinatra>.freeze, ["~> 1.4"])
    s.add_dependency(%q<sinatra-contrib>.freeze, ["~> 1.4"])
    s.add_dependency(%q<addressable>.freeze, ["~> 2.4"])
    s.add_dependency(%q<oj>.freeze, ["~> 3.3", ">= 3.3.2"])
    s.add_dependency(%q<bundler>.freeze, ["~> 1.7"])
    s.add_dependency(%q<rake>.freeze, ["~> 10.0"])
    s.add_dependency(%q<rspec>.freeze, ["~> 3.4"])
    s.add_dependency(%q<rubocop>.freeze, ["~> 0.48.1"])
    s.add_dependency(%q<sinatra-cross_origin>.freeze, ["~> 0.3"])
    s.add_dependency(%q<gem-release>.freeze, ["~> 0.7"])
  end
end
