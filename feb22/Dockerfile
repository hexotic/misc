FROM ubuntu:20.04
RUN apt-get update
RUN apt-get install -y python3 sudo build-essential git vim
RUN apt-get install -y iproute2 iputils-ping
COPY ./vpp/build-root/install-vpp_debug-native/vpp/bin/ /usr/bin/
