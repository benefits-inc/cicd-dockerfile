FROM ubuntu

ENV TZ=Asia/Seoul

ENV container docker

RUN apt-get update && apt-get upgrade -y
RUN apt install -y init systemd
# RUN apt install -y build-essential  
RUN apt install -y vim curl
RUN apt install -y sudo wget 
RUN apt install -y net-tools iputils-ping

# Sentinel install
RUN apt install -y redis-sentinel
# /etc/redis/sentinel.conf
# 바인드 주소 172.24.0.4 명시
RUN sed -i 's/bind 127.0.0.1 ::1/bind 172.24.0.4 127.0.0.1 ::1/' /etc/redis/sentinel.conf
# 바인드 주소 172.24.0.2 마스터의 주소, 2는 3개 중 다수결 2/3 sentinel
RUN sed -i 's/monitor mymaster 127.0.0.1 6379 2/monitor mymaster 172.24.0.2 6379 2/' /etc/redis/sentinel.conf

# SSH
RUN apt install -y openssh-server
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN echo 'root:benefits' | chpasswd
# RUN ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa
#RUN apt-get install -y openssh-clients

RUN apt-get clean autoclean
RUN apt-get autoremove -y
RUN rm -rf /var/lib/{apt,dpkg,cache,log}

# home 으로 초기화
WORKDIR /root

EXPOSE 22

VOLUME ["/sys/fs/cgroup"]

#ENTRYPOINT ["/usr/sbin/init" "systemctl" "start" "sshd"]
CMD ["/usr/sbin/init" "systemctl" "start" "sshd"]
