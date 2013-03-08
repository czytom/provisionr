provisionr
==========

# How to install Gentoo as a XEN Guest (domU) 
- prepare system partitions
- mount partitons in designed system layout under /mnt path (probably best choice is /mnt/gentoo).
- run script provision.rb script adapt all parameters to your needs, example use:
```scss
ruby provision.rb --chroot-dir=/mnt/gentoo --nameserver '10.5.0.20' --network 'eth0:10.5.6.7/16 eth1:10.6.7.8/16' --routes 'eth0:default:10.5.0.1 eth1:10.5.0.1/24:10.3.3.3' --hostname "test11" --xen 'cpu:1,memory:2048,network:bridge=br5,config_path:/opt/xen/configs/gentoo/'  --swap_partition '/dev/mapper/goscinny11-test1_swap' --root-password 'something'
```
After finish, your machine is ready to run. Simply start it with xl create command. Machine XEN config is generated under pointed path (config_path in --xen option)

# Install Gentoo as a physical machine
Not finished yet ...


