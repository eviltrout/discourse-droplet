require 'rubygems'
require 'bundler/setup'

Bundler.require(:default)

Rye::Cmd.add_command :launcher, './launcher'
Rye::Cmd.add_command :keygen, "ssh-keygen"
Rye::Cmd.add_command :dd, "dd"
Rye::Cmd.add_command :mkswap, "mkswap"
Rye::Cmd.add_command :swapon, "swapon"
Rye::Cmd.add_command :swap_fstab, 'echo "/swapfile       none    swap    sw      0       0" >> /etc/fstab'
Rye::Cmd.add_command :swapiness, 'echo 0 | tee /proc/sys/vm/swappiness'

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

if keys.nil? || keys.empty?
  puts "ERROR: You need to upload a ssh key to digital ocean and use working credentials"
  exit
end
ssh_key_id = keys[0]['id']

puts "SMTP Host: (empty for none, not recommended)"
smtp_host = gets.chomp
puts

unless smtp_host.empty?
  puts "SMTP Port:"
  smtp_port = gets.chomp
  puts

  puts "SMTP Username:"
  smtp_username = gets.chomp
  puts

  puts "SMTP Password:"
  smtp_password = gets.chomp
  puts
end

puts
puts "Confirm Your Settings"
puts "=====================\n"
puts "Host: #{host}"
puts "Email: #{email}"
puts "SSH Key: #{keys[0]['name']}"
unless smtp_host.empty?
  puts "SMTP Host: #{smtp_host}"
  puts "SMTP Port: #{smtp_port}"
  puts "SMTP Username: #{smtp_username}"
  puts "SMTP Password: #{smtp_password}"
end
puts


response = ""
while response.downcase != 'y'
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

puts "Removing any old SSH host entries (digital ocean reuses them)"
system "ssh-keygen -R #{droplet['ip_address']}" if File.exists?(File.expand_path("~/.ssh/known_hosts"))

puts "Initializing Droplet (#{droplet_id}) #{droplet['ip_address']}..."
attempts = 0
begin
  rbox =Rye::Box.new(droplet['ip_address'], user: 'root', timeout: 10)
  rbox.mkdir :p, '/var/docker/data'
rescue Timeout::Error, Net::SSH::Disconnect
  attempts += 1
  if attempts < 20
    puts "Retrying SSH... Attempt: #{attempts}"
    sleep 10
    retry
  end
  puts "Couldn't connect via SSH"
end

puts "Creating Swap"
rbox.dd 'if=/dev/zero', 'of=/swapfile', 'bs=1024', 'count=1024k'
rbox.mkswap '/swapfile'
rbox.swapon "/swapfile"
rbox.disable_safe_mode
rbox.swap_fstab
rbox.swapiness
rbox.chown 'root:root', '/swapfile'
rbox.chmod '0600', '/swapfile'
rbox.enable_safe_mode


rbox.cd '/var/docker'
result = rbox.ls('/var/docker').to_s
if result !~ /discourse_docker/
  puts "Checking out discourse_docker..."
  rbox.git 'clone', 'https://github.com/SamSaffron/discourse_docker.git'
end

# Generate a SSH key to shell into docker with
puts "Generating SSH key"
rbox.keygen '-t', 'rsa', '-f', '/root/.ssh/id_rsa', '-N', ''
pub_key = rbox.cat("/root/.ssh/id_rsa.pub").to_s

puts "Customizing config file..."
config = YAML.load(rbox.cat("/var/docker/discourse_docker/samples/standalone.yml").to_s)
config['params']['ssh_key'] = pub_key
config['env']['DISCOURSE_HOSTNAME'] = host
config['env']['DISCOURSE_DEVELOPER_EMAILS'] = email

unless smtp_host.empty?
  config['env']['DISCOURSE_SMTP_ADDRESS'] = smtp_host
  config['env']['DISCOURSE_SMTP_PORT'] = smtp_port
  config['env']['DISCOURSE_SMTP_USER_NAME'] = smtp_username
  config['env']['DISCOURSE_SMTP_PASSWORD'] = smtp_password
end

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
puts
puts "If you get a Gateway 502 error, try again in a few seconds; Rails is still likely starting up."
