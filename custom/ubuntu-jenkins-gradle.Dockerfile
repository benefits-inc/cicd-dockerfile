#########################################
## 실제 사용 안함. jenkins 내부에서 gradle 사용
## 기록 용
#########################################
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

# git : 이미 설치 되어있음 명시 목적
RUN apt-get install -y git

RUN apt-get install -y unzip

# gralde 설치
WORKDIR /opt
RUN wget https://services.gradle.org/distributions/gradle-8.5-bin.zip
RUN unzip gradle-8.5-bin.zip
RUN mv gradle-8.5 gradle
RUN rm -rf gradle-8.5-bin.zip

# maven 환경변수 등록
ENV PATH="$PATH:/opt/gradle/bin"

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
