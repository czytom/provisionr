require 'optparse'
require './stage3.rb'
require './shadow.rb'
require 'erb'
require './devices.rb'

#name: get stage3 tarball
TEMPLATE_PATH = './templates'
class Configuration
  include Singleton

  def initialize
    @options = {}
    optparse = OptionParser.new do|opts|
      # Set a banner, displayed at the top
      # of the help screen.
      opts.banner = "Usage: command [options]"

      @options[:verbose] = false
      opts.on( '-v', '--verbose', 'Output more information' ) do
        @options[:verbose] = true
      end

      @options[:puppet] = false
      opts.on( '-p', '--with_puppet', 'Install puppet package' ) do
        @options[:puppet] = true
      end

      #TODO required options
      @options[:chroot_dir] = ''
      opts.on( '-R', '--chroot-dir String', :required,  "Chroot dir - must be under /mnt path" ) do|l|
        @options[:chroot_dir] = l
      end

      @options[:root_password] = ''
      opts.on( '-R', '--root-password String', :required,  "Set root password" ) do|l|
        @options[:root_password] = l
      end

      @options[:routes] = ''
      opts.on( '-R', '--routes String', :required,  "Configure network routing" ) do |l|
	routes = Hash.new
	l.split.each do |i|
	  routes[i.split(':')[0]] ||= Hash.new
	  routes[i.split(':')[0]][i.split(':')[1]] = i.split(':')[2]
	end
        @options[:routes] = routes
      end

      @options[:networks] = ''
      opts.on( '-W', '--networks String', :required,  "Configure networking" ) do |l|
	network = Hash.new
	l.split.each {|i| network[i.split(':')[0]] = i.split(':')[1]} 
        @options[:networks] = network
      end

      @options[:swap_partition] = ''
      opts.on( '-s', '--swap_partition String', :required,  "Configure swap space" ) do |l|
        @options[:swap_partition] = l
      end

      @options[:nameserver] = ''
      opts.on( '-N', '--nameserver String', :required,  "Configure nameserver" ) do |l|
        @options[:nameserver] = l
      end

      @options[:arch] = 'amd64'
      opts.on( '-a', '--arch String', :required,  "Configure host architecture default x86" ) do |l|
          @options[:arch] = l
      end

      @options[:xen] = {}
      opts.on( '-X', '--xen String', :required,  "Configure host under Xen" ) do |l|
	l.split(',').each do |i|
          @options[:xen][i.split(':')[0]] = i.split(':')[1]
	end
      end

      @options[:hostname] = ''
      opts.on( '-H', '--hostname String', :required,  "Configure hostname" ) do |l|
        @options[:hostname] = l
      end

      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        exit
      end
    end
    optparse.parse!
  end

  def get(name)
    @options[name]
  end
end

#options[:host] = ask("Enter rsync server address:  ") { |q| q.echo = true } if options[:host] == ''

def render(render_set)
  template_path = File.expand_path(TEMPLATE_PATH) + render_set[:file] + '.erb'
  destination_path = Configuration.instance.get(:chroot_dir) + render_set[:file]
  unless render_set[:destination].nil? then
    destination_path = render_set[:destination]
  end
  content = File.read(template_path)
  t = ERB.new(content,0,'>')
  File.open(destination_path, 'w') {|f| f.write(t.result(binding)) }
end
#TODO

def create_symlink(link_name, options = {})
  target = link_name
  unless options[:target].nil?
    target = options[:target]
  end
  system("ln -sfn /etc/init.d/#{target} #{Configuration.instance.get(:chroot_dir)}/etc/init.d/#{link_name}")
end

def add_to_runlevel(name, options = {} )
  system("chroot #{Configuration.instance.get(:chroot_dir)} rc-update add #{name}")
end

#  - name: unpack stage3 tarball
#p Devices.instance.get_mounts.sort_by{|l| l.length}
#exit
Stage3.instance.set_arch(Configuration.instance.get(:arch))
Stage3.instance.fetch_and_unpack(Configuration.instance.get(:chroot_dir))


#create console device and null in /dev
##TODO unnecessery probably?
system("mknod #{Configuration.instance.get(:chroot_dir)}/dev/console c 5 1")
system("mknod #{Configuration.instance.get(:chroot_dir)}/dev/null c 1 3")

#  - name: add ssh o autostart
add_to_runlevel("sshd")
  
#  - name: configure resolver
render ({:file => '/etc/resolv.conf'})

#    tags: prepare_system_net
#  - name: add net.eth0 script

Configuration.instance.get(:networks).each_pair do |interface, config| 
  interface_name = 'net.' + interface
  create_symlink('net.' + interface,{:target => 'net.lo'})
  add_to_runlevel(interface_name)
end

#  - name: render net
render ({:file => '/etc/conf.d/net'})

#  - name: configure hostname
render ({:file => '/etc/conf.d/hostname'})

#  - name: configure fstab
render({:file => '/etc/fstab'})

#  - name: configure xen domU
render({:file => '/opt/xen/configs/xen', :destination => "/opt/xen/configs/gentoo/#{Configuration.instance.get(:hostname)}"})

#render inittab
render ({:file => '/etc/inittab'})

#render securetty
render ({:file => '/etc/securetty'})

# - name: set root password
password_sha = Shadow.password( Configuration.instance.get(:root_password))
command = "sed -i \'s#root:\\*#root:" + password_sha + "#g\' " + Configuration.instance.get(:chroot_dir) + "/etc/shadow"
system(command)

#todo bind /dev

#chroot
system("chroot #{Configuration.instance.get(:chroot_dir)} emerge --sync")
#set profile
## TODO - add options to set profile
system("chroot #{Configuration.instance.get(:chroot_dir)} eselect profile set 1")

system("chroot #{Configuration.instance.get(:chroot_dir)} emerge -u gentoo-sources")
#OPTIONAL - PUPPET
if Configuration.instance.get(:puppet) then
  command = "echo \'=sys-apps/net-tools-1.60_p20120127084908 old-output\' \>\> " + Configuration.instance.get(:chroot_dir) + "/etc/portage/package.use"
  system(command)
  system("chroot #{Configuration.instance.get(:chroot_dir)} emerge -u puppet")
end

# #grub config
#TODO install grub if physical machine
system("mkdir -p #{Configuration.instance.get(:chroot_dir)}/boot/grub")
render({:file => "/boot/grub/grub.conf"})

#compile kernel
##TODO - check architecture
#TODO absolute path- 
system("cp ./scripts/kernel_compile.sh #{Configuration.instance.get(:chroot_dir)}")
#TODO - get correct config
system("cp ./config/kernel-xen-#{Configuration.instance.get(:arch)} #{Configuration.instance.get(:chroot_dir)}/usr/src/linux/.config")

system("chroot #{Configuration.instance.get(:chroot_dir)} /kernel_compile.sh")
#TODO - remove correct script
system("rm #{Configuration.instance.get(:chroot_dir)}/kernel_compile.sh")
