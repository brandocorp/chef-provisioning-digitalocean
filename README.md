# chef-provisioning-digitalocean

Provisioner for creating Digital Ocean droplets in Chef Provisioning.

## Example

```ruby

require 'chef/provisioning/digitalocean_driver'

with_driver 'digitalocean', { access_token: ENV['DIGITALOCEAN_ACCESS_TOKEN'] }

with_machine_options({
  bootstrap_options: {
    region: 'sfo1',
    size: '512mb',
    image: 'ubuntu-14-04-x64',
    ssh_keys: ['digitalocean']
  }
})

machine 'my_droplet'

```
