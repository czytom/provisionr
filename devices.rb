require 'singleton'

class Devices
  include Singleton
  def initialize
    @swap_partition = 2
    vm_partition_prefix = '/dev/xvda'
    @chroot_dir = Configuration.instance.get(:chroot_dir).chomp('/')
    @mounts = [{},{ :chroot_mount_point => 'none', :type => "swap", :device => Configuration.instance.get(:swap_partition), :fs_passno => 0, :vm_partition => "#{vm_partition_prefix}#{@swap_partition}"}]
    xen_partition = 3
    IO.popen("mount").each do |mount|
	next if mount.match /^proc on.*/
	next if mount.match /^\/proc on.*/
	if mount.match /(^.*) on (#{@chroot_dir}.*) type (.*) /
		#tricky to resolve how to get only / when slicing string
		chroot_mount = '/' + $2[@chroot_dir.length+1..-1].to_s
		fs_passno = 2
		if chroot_mount == '/'
		  @mounts[0] = { :chroot_mount_point => chroot_mount, :type => $3, :device => $1, :base_mount_point => $2, :fs_passno => 1, :vm_partition => "#{vm_partition_prefix}1"}
		else
		  @mounts << { :chroot_mount_point => chroot_mount, :type => $3, :device => $1, :base_mount_point => $2, :fs_passno => 2, :vm_partition => "#{vm_partition_prefix}#{xen_partition}"}
		  xen_partition += 1
		end
	end
    end
  end


  def get_mounts
    @mounts
  end

end
