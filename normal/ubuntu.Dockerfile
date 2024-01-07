FROM ubuntu

ENV TZ=Asia/Seoul

ENV container docker

RUN apt-get update && apt-get upgrade -y \ 
  && apt install -qq -y init systemd \ 
  && apt install -qq -y build-essential \ 
  && apt install -qq -y vim curl \ 
  && apt install -qq -y net-tools iputils-ping \ 
  && apt-get clean autoclean \ 
  && apt-get autoremove -y \ 
  && rm -rf /var/lib/{apt,dpkg,cache,log}

VOLUME ["/sys/fs/cgroup"]
CMD ["/usr/sbin/init"]
