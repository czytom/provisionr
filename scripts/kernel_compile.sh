#!/bin/bash

cd /usr/src/linux
#create symlinks
version=`make kernelversion`
for name in vmlinuz System.map config; do 
  echo $name $version
  ln -s /boot/${name}-${version} /boot/${name}
done

make
make modules
make modules_install
make install
