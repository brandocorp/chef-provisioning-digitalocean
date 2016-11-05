require 'chef/provisioning/digitalocean_driver'

Chef::Provisioning.register_driver_class('digitalocean', Chef::Provisioning::DigitalOceanDriver::Driver)
