# VPP notes

# Build in container

https://s3-docs.fd.io/vpp/22.02/developer/build-run-debug/building.html

/!\ Building VPP in a container requires 8GB of RAM. Docker resources need to be increased.

Clone repo and launch container to build

```
git clone https://gerrit.fd.io/r/vpp
docker run --name vpp_build -it -v $PWD/vpp:/vpp ubuntu:20.04
```

## In the container
```sh
apt-get update
apt-get install -y build-essential git vim
apt-get install -y python3 sudo

make install-dep
make install-ext-deps
make build
```

Quick test:
```
gdb --args $PWD/build-root/install-vpp_debug-native/vpp/bin/vpp "unix {interactive }"
```

### Basic `startup.conf`

```
unix {nodaemon cli-listen /run/vpp/cli-vpp1.sock}
plugins { plugin dpdk_plugin.so { disable } }
```

## Run VPP in a container

https://s3-docs.fd.io/vpp/22.02/gettingstarted/progressivevpp/runningvpp.html

## Problem of ip link add

https://stackoverflow.com/questions/27708376/why-am-i-getting-an-rtnetlink-operation-not-permitted-when-using-pipework-with-d

Requires --privileged and maybe --cap-add=NET_ADMIN

Dockerfile for runtime:

```sh
cat << EOF > Dockerfile
FROM ubuntu:20.04
RUN apt-get update
RUN apt-get install -y python3 sudo build-essential git vim
RUN apt-get install -y iproute2 iputils-ping
COPY ./VPP_BUILD/vpp/build-root/install-vpp_debug-native/vpp/bin/ /usr/bin/
EOF

docker build -t ubuntu_run .

docker run -it --name my_vpp --privileged -v $PWD/vpp:/vpp --cap-add=NET_ADMIN ubuntu_run
```

In the container:
```sh
cat << EOF > /tmp/startup1.conf
unix {nodaemon cli-listen /run/vpp/cli-vpp1.sock}
plugins {
   path /vpp/build-root/install-vpp_debug-native/vpp/lib/x86_64-linux-gnu/vpp_plugins
   plugin dpdk_plugin.so { disable }
}
EOF

/usr/bin/vpp -c /tmp/startup1.conf > /dev/null 2>&1 &
vppctl -s /run/vpp/cli-vpp1.sock
```

# Creating an interface

https://s3-docs.fd.io/vpp/22.02/gettingstarted/progressivevpp/interface.html

## Topology

```
vpp1host 10.10.1.1/24 <=====> host-vpp1out 10.10.1.2/24 [vpp1]
```

1. Create a veth interface in Linux host
2. Assign an IP address to one end of the veth interface in the Linux host
3. Create a vpp host-interface that connected to one end of a veth interface via AF_PACKET
4. Add an ip address to a vpp interface

## Create a veth and assign IP

Create a **vpp1out** and **vpp1host**

```sh
ip link add name vpp1out type veth peer name vpp1host
ip link set dev vpp1out up
ip link set dev vpp1host up
ip addr add 10.10.1.1/24 dev vpp1host
ip addr show vpp1host
```

Results:
```sh
root@9e43e702f7f7:/# ip addr show vpp1host
4: vpp1host@vpp1out: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether c6:c1:2d:a5:0c:ca brd ff:ff:ff:ff:ff:ff
    inet 10.10.1.1/24 scope global vpp1host
       valid_lft forever preferred_lft forever
```

## Start vpp

```sh
cat << EOF > /tmp/startup1.conf
unix {nodaemon cli-listen /run/vpp/cli-vpp1.sock}
plugins {
   path /vpp/build-root/install-vpp_debug-native/vpp/lib/x86_64-linux-gnu/vpp_plugins
   plugin dpdk_plugin.so { disable }
}
EOF

/usr/bin/vpp -c /tmp/startup1.conf > /dev/null 2>&1 &
vppctl -s /run/vpp/cli-vpp1.sock
```

VPP commands to create interface:

```
create host-interface name vpp1out
set int state host-vpp1out up
show int
set int ip address host-vpp1out 10.10.1.2/24
show int addr
show hardware

show trace
clear trace
trace add af-packet-input 10
q
```

NOTE: trace add input graph node in page:<br>
https://fd.io/docs/vpp/v2101/gettingstarted/progressivevpp/traces.html

In container:

```sh
ping -c 1 10.10.1.2
```

* Look at trace `show trace`, `clear trace`
* Ping from VPP: `ping 10.10.1.1`, `show trace`
* ARP and routing table:

```
show ip neighbors
show ip fib    # routing table
```

# Connecting two FD.io VPP instances

https://s3-docs.fd.io/vpp/22.02/gettingstarted/progressivevpp/twovppinstances.html

```sh
cat << EOF > /tmp/startup2.conf
unix {nodaemon cli-listen /run/vpp/cli-vpp2.sock}
plugins {
   path /vpp/build-root/install-vpp_debug-native/vpp/lib/x86_64-linux-gnu/vpp_plugins
   plugin dpdk_plugin.so { disable }
}

/usr/bin/vpp -c /tmp/startup2.conf &
vppctl -s /run/vpp/cli-vpp2.sock
```

* check

```
show version
q
```

## Create memif interface on vpp1

`vppctl -s /run/vpp/cli-vpp1.sock`

```
create interface memif id 0 master
set int state memif0/0 up
set int ip address memif0/0 10.10.2.1/24
show int addr
```

```
clear trace
trace add memif-input 10
```

## Create memif interface on vpp2

`vppctl -s /run/vpp/cli-vpp2.sock`

```
create interface memif id 0 slave
set int state memif0/0 up
set int ip address memif0/0 10.10.2.2/24
show int addr
```

```
clear trace
trace add memif-input 10
```

## Ping from vpp1 to vpp2

From vpp1 `ping 10.10.2.2`

From vpp2 `ping 10.10.2.1`

# Routing

## Setup host route

```sh
ip route add 10.10.2.0/24 via 10.10.1.2
ip route
```

output:

```
default via 172.17.0.1 dev eth0
10.10.1.0/24 dev vpp1host proto kernel scope link src 10.10.1.1
10.10.2.0/24 via 10.10.1.2 dev vpp1host
172.17.0.0/16 dev eth0 proto kernel scope link src 172.17.0.4
```

## Setup return route on vpp2

```
vppctl -s /run/vpp/cli-vpp2.sock
ip route add 10.10.1.0/24 via 10.10.2.1
clear trace
trace add af-packet-input 10
trace add memif-input 10
```

(add trace on vpp1 too)

## Ping from host through vpp1 to vpp2

```sh
ping 10.10.2.2
```

# Switching

```
vpp1host 10.10.1.1/24 <===> host-vpp1out [vpp1] host-vpp1vpp2 <===> host-vpp1vpp2 [vpp2] loop0: 10.10.1.2/24 
```

## Clean environment

Start from a clean environment:

```sh
ps -ef | grep vpp | awk '{print $2}'| xargs sudo kill
ip link del dev vpp1host
ip link del dev vpp1vpp2  # created in this section
```

```sh
/usr/bin/vpp -c /tmp/startup1.conf > /dev/null 2>&1 &
/usr/bin/vpp -c /tmp/startup2.conf > /dev/null 2>&1 &
```

## Connect vpp1 to host

Create a **vpp1out** and **vpp1host**

* create veth: in a terminal:

```sh
ip link add name vpp1out type veth peer name vpp1host
ip link set dev vpp1out up
ip link set dev vpp1host up
ip addr add 10.10.1.1/24 dev vpp1host
ip addr show vpp1host
```

* in vpp: `vppctl -s /run/vpp/cli-vpp1.sock`

```
create host-interface name vpp1out
set int state host-vpp1out up
show int
show int addr
show hardware
```

## Connect vpp1 to vpp2

* create veth: in a terminal:

```sh
ip link add name vpp1vpp2 type veth peer name vpp2vpp1
ip link set dev vpp1vpp2 up
ip link set dev vpp2vpp1 up
ip addr show vpp1vpp2
```

* connect **vpp1vpp2** to vpp1: `vppctl -s /run/vpp/cli-vpp1.sock`

```
create host-interface name vpp1vpp2
set int state host-vpp1vpp2 up
show int
show hardware
```

* connect **vpp2vpp1** to vpp2: `vppctl -s /run/vpp/cli-vpp2.sock`

```
create host-interface name vpp2vpp1
set int state host-vpp2vpp1 up
show int
show hardware
```

## Configure bridge domain on vpp1

```
DBGvpp# show bridge-domain
no bridge-domains in use
```

NOTE: there might be a bridge domain ID '0' but no operations are supported.
<br>
=> Need to create a bridge

In vpp1:

```
set int l2 bridge host-vpp1out 1
set int l2 bridge host-vpp1vpp2 1
show bridge-domain 1 detail
```

## Configure loopback interface on vpp2

```
create loopback interface
set int state loop0 up
set int ip address loop0 10.10.1.2/24
show int
```

## Configure bridge domain on vpp2

* Add interface **loop0** as a bridge virtual interface (bvi) to bridge domain 1
* Add interface **vpp2vpp1** to bridge domain 1

```
set int l2 bridge loop0 1 bvi
set int l2 bridge host-vpp2vpp1 1
```

## Add trace

```sh
clear trace
trace add af-packet-input 10
```

## Ping from host to vpp and vpp to host

1. ping from host to 10.10.1.2
2. Examine and clear trace on vpp1 and vpp2
3. ping from vpp2 to 10.10.1.1
4. Examine and clear trace on vpp1 and vpp2

## Examine l2 fib

`show l2fib verbose`

# Trace possibilities

```
af-packet-input
avf-input
bond-process
dpdk-crypto-input
dpdk-input
handoff-trace
ixge-input
memif-input
mrvl-pp2-input
netmap-input
p2p-ethernet-input
pg-input
punt-socket-rx
rdma-input
session-queue
tuntap-rx
vhost-user-input
virtio-input
vmxnet3-input
```
