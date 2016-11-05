$:.unshift(File.dirname(__FILE__) + '/lib')
require 'chef/provisioning/digitalocean_driver/version'

Gem::Specification.new do |s|
  s.name = 'chef-provisioning-digitalocean'
  s.version = Chef::Provisioning::DigitalOceanDriver::VERSION
  s.platform = Gem::Platform::RUBY
  s.extra_rdoc_files = ['README.md', 'LICENSE' ]
  s.summary = 'Provisioner for creating Digital Ocean droplets in Chef Provisioning.'
  s.description = s.summary
  s.author = 'Brandon Raabe'
  s.email = 'brandocorp@gmail.com'
  s.homepage = 'https://github.com/chef/chef-provisioning-digitalocean'
  s.license = 'MIT'

  s.required_ruby_version = ">= 2.0.0"

  s.add_dependency 'chef-provisioning', '>= 1.0', '< 3.0'

  s.add_dependency 'droplet_kit', '~> 2.0'

  s.bindir       = "bin"
  s.executables  = %w( )

  s.require_path = 'lib'
  s.files = %w(Gemfile Rakefile LICENSE README.md) + Dir.glob("*.gemspec") +
      Dir.glob("{distro,lib,tasks,spec}/**/*", File::FNM_DOTMATCH).reject {|f| File.directory?(f) }
end
