require 'rubygems'
require 'bundler/setup'

Bundler.require(:default)

Rye::Cmd.add_command :launcher, './launcher'

puts "Your Digital Ocean Client id:"
Digitalocean.client_id = gets.chomp
puts

puts "Your Digital Ocean API Key:"
Digitalocean.api_key = gets.chomp
puts

puts "Your developer email address:"
email = gets.chomp
puts

puts "Host of Discourse forum (example: eviltrout.com)"
host = gets.chomp
puts

keys = Digitalocean::SshKey.all['ssh_keys']
if keys.empty?
  puts "ERROR: You need to upload a ssh key to digital ocean"
  exit
end

ssh_key_id = keys[0]['id']

puts
puts "Confirm Your Settings"
puts "=====================\n"
puts "Host: #{host}"
puts "Email: #{email}"
puts "SSH Key: #{keys[0]['name']}"
puts

response = nil
while response != 'y'
  puts "Type 'Y' to continue"
  response = gets.chomp
end
puts
puts "Creating #{host}..."


droplet = Digitalocean::Droplet.create(name: host, size_id: 63, image_id: 1341147, region_id: 4, ssh_key_ids: ssh_key_id)['droplet']
droplet_id = droplet['id']


print "Waiting for #{host} (#{droplet_id}) to become active..."

droplet = Digitalocean::Droplet.retrieve(droplet_id)['droplet']
while droplet['status'] != 'active'
  sleep 5
  droplet = Digitalocean::Droplet.retrieve(droplet_id)['droplet']
  print '.'
end
print "\n"

puts "Waiting for a few seconds..."
sleep 30

puts "Initializing droplet (#{droplet_id}) #{droplet['ip_address']} ..."
rbox = Rye::Box.new(droplet['ip_address'], user: 'root')
rbox.mkdir :p, '/var/docker/data'
rbox.cd '/var/docker'
result = rbox.ls('/var/docker').to_s
if result !~ /discourse_docker/
  puts "Checking out discourse_docker..."
  rbox.git 'clone', 'https://github.com/SamSaffron/discourse_docker.git'
end

puts "Customizing config file..."
config = YAML.load(rbox.cat("/var/docker/discourse_docker/samples/standalone.yml").to_s)
config['params']['ssh_key'] = Digitalocean::SshKey.retrieve(ssh_key_id)['ssh_key']['ssh_pub_key']
config['env']['DISCOURSE_HOSTNAME'] = host
config['env']['DISCOURSE_DEVELOPER_EMAILS'] = email

app_yml = StringIO.new(config.to_yaml)
rbox.file_upload app_yml, "/var/docker/discourse_docker/containers/app.yml"

puts "Bootstrapping image..."
rbox.cd '/var/docker/discourse_docker'

rbox.launcher 'bootstrap', 'app'
puts "Starting Discourse..."
rbox.launcher 'start', 'app'

puts "Discourse is ready to use:"
puts "http://#{host}"
puts "http://#{droplet['ip_address']}"