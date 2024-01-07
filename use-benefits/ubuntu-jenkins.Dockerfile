FROM ubuntu

ENV TZ=Asia/Seoul

ENV container docker

RUN apt-get update && apt-get upgrade -y
RUN apt install -y init systemd
# RUN apt install -y build-essential  
RUN apt install -y vim curl
RUN apt install -y sudo wget 
RUN apt install -y net-tools iputils-ping

# SSH
RUN apt install -y openssh-server
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN echo 'root:benefits' | chpasswd
# RUN ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa
#RUN apt-get install -y openssh-clients

# jenkins, jdk 17: https://www.jenkins.io/download/
RUN sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
RUN echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
    /etc/apt/sources.list.d/jenkins.list > /dev/null
RUN apt-get update
RUN apt-get install -y fontconfig openjdk-17-jre
RUN apt-get install -y jenkins

# apt-get cache clean
RUN apt-get clean autoclean
RUN apt-get autoremove -y
RUN rm -rf /var/lib/{apt,dpkg,cache,log}

# home 으로 초기화
WORKDIR /root

EXPOSE 22
EXPOSE 8080

VOLUME ["/sys/fs/cgroup"]

#ENTRYPOINT ["/usr/sbin/init" "systemctl" "start" "sshd"]
CMD ["/usr/sbin/init" "systemctl" "start" "sshd"]
