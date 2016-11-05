require 'droplet_kit'
require 'pry'
require 'chef/provisioning/transport/ssh'
require 'chef/provisioning/convergence_strategy/install_cached'
require 'chef/provisioning/machine/unix_machine'

class Chef
module Provisioning
module DigitalOceanDriver
  class Driver < Chef::Provisioning::Driver
    def self.from_url(driver_url, config)
      Driver.new(driver_url, config)
    end

    def self.canonicalize_url(driver_url, config)
      [ driver_url, config ]
    end

    def initialize(driver_url, config)
      super
    end

    def digitalocean
      DropletKit::Client.new(access_token: digitalocean_access_token)
    end

    def digitalocean_access_token
      ENV['DIGITALOCEAN_ACCESS_TOKEN'] || driver_options[:access_token]
    end

    def allocate_machine(action_handler, machine_spec, machine_options)
      if machine_spec.reference
        unless droplet_exists?(machine_spec.reference['server_id'])
          action_handler.perform_action "Droplet #{machine_spec.reference['server_id']} does not really exist. Recreating droplet..." do
            machine_spec.reference = nil
          end
        end
      end

      ssh_keys = normalize_ssh_keys(machine_options[:bootstrap_options][:ssh_keys])

      unless machine_spec.reference
        action_handler.perform_action "Creating droplet #{machine_spec.name} with options #{machine_options}" do
          droplet_spec = DropletKit::Droplet.new(name: machine_spec.name, ssh_keys: ssh_keys, **machine_options[:bootstrap_options])
          droplet = digitalocean.droplets.create(droplet_spec)
          machine_spec.reference = {
            'driver_url' => driver_url,
            'driver_version' => DigitalOceanDriver::VERSION,
            'allocated_at' => Time.now.utc.to_s,
            'server_id' => droplet.id,
            'ssh_keys' => ssh_keys
          }
        end
      end
    end

    def ready_machine(action_handler, machine_spec, machine_options)
      droplet = digitalocean.droplets.find(id: machine_spec.reference['server_id'])
      if droplet.status == 'off'
        action_handler.perform_action "Powering on droplet #{droplet.id}" do
          digitalocean.droplet_actions.power_on(droplet_id: droplet.id)
        end
      end

      if droplet.status != 'active'
        action_handler.perform_action "Wait for droplet #{droplet.id}" do
          wait_for_droplet(droplet, 'active')
        end
      end

      wait_for_transport(action_handler, machine_spec, machine_options)

      # Return the Machine object
      machine_for(machine_spec, machine_options)
    end

    def destroy_machine(action_handler, machine_spec, machine_options)
      if machine_spec.reference
        if droplet_exists?(machine_spec.reference['server_id'])
          action_handler.perform_action "Destroying droplet #{machine_spec.name}" do
            digitalocean.droplets.delete(id: machine_spec.reference['server_id'])
          end
        else
          action_handler.perform_action "Droplet #{machine_spec.reference['server_id']} does not exist..." do
            machine_spec.reference = nil
          end
        end
      end
    end

    def stop_machine(action_handler, machine_spec, machine_options)
      if machine_spec.reference
        if droplet_exists?(machine_spec.reference['server_id'])
          action_handler.perform_action "Stopping droplet #{machine_spec.name}" do
            digitalocean.droplet_actions.shutdown(droplet_id: machine_spec.reference['server_id'])
          end
        else
          action_handler.perform_action "Droplet #{machine_spec.reference['server_id']} does not exist..." do
            machine_spec.reference = nil
          end
        end
      end
    end

    def connect_to_machine(machine_spec, machine_options)
      machine_for(machine_spec, machine_options)
    end

    def machine_for(machine_spec, machine_options)
      transport = transport_for(machine_spec, machine_options)
      convergence_strategy = Chef::Provisioning::ConvergenceStrategy::InstallCached.new(machine_options[:convergence_options], {})
      Chef::Provisioning::Machine::UnixMachine.new(machine_spec, transport, convergence_strategy)
    end

    # This is minimal code, there should be a timeout here...
    def wait_for_droplet(droplet, status)
      loop do # infinite loop!
        sleep 3
        droplet = digitalocean.droplets.find(id: droplet.id)
        break if droplet.status == status
      end
    end

    def transport_for(machine_spec, machine_options)
      droplet = digitalocean.droplets.find(id: machine_spec.reference['server_id'])
      hostname = droplet_public_ip_address(droplet)
      username = 'root'
      ssh_options = {
        :keys => [],
        :keys_only => true,
        :key_data => machine_options[:bootstrap_options][:ssh_keys].map { |key| get_private_key(key) }
      }
      Chef::Provisioning::Transport::SSH.new(hostname, username, ssh_options, {}, config)
    end

    def wait_for_transport(action_handler, machine_spec, machine_options)
      transport = transport_for(machine_spec, machine_options)

      if action_handler.should_perform_actions
        action_handler.report_progress "Waiting for #{machine_spec.name} to be connectable..."
      end
      loop do
        # Terrible, infinite loop again?!
        break if transport.available?
        sleep 30
        action_handler.report_progress "Waiting 30s for #{machine_spec.name} to be connectable..."
      end
    end

    def droplet_exists?(id)
      begin
        digitalocean.droplets.find(id: id)
        true
      rescue DropletKit::Error
        false
      end
    end

    def droplet_public_ip_address(droplet)
      net = droplet.networks.v4.find {|net| net.type == 'public' }
      net.ip_address
    end

    def normalize_ssh_keys(key_list)
      keys = key_list.map do |key|
        target = key_for(:id, key)
        target = key_for(:fingerprint, key) unless target
        target = key_for(:name, key) unless target
        target
      end

      # remove nils
      keys.reject {|key| key.nil? }

      # return the key fingerprints
      keys.map(&:fingerprint)
    end

    def key_for(attribute, value)
      all_keys = digitalocean.ssh_keys.all
      all_keys.find {|key| key.send(attribute) == value }
    end
  end
end
end
end
