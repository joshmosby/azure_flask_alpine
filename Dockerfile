FROM python:2.7.15-alpine3.8

COPY sshd_config /etc/ssh/

RUN apk --update add g++ \
    libffi-dev \
    openssl-dev \
    openssh \
    openrc \
    bash \
    && echo "root:Docker!" | chpasswd \
    && echo "cd /home" >> /etc/bash.bashrc 

# Add rsyslog
ADD http://alpine.adiscon.com/rsyslog@lists.adiscon.com-5a55e598.rsa.pub /etc/apk/keys
RUN echo 'http://alpine.adiscon.com/3.7/stable' >> /etc/apk/repositories
RUN apk add rsyslog
# Fixing issues from https://github.com/gliderlabs/docker-alpine/issues/42
RUN  \
    # Tell openrc its running inside a container, till now that has meant LXC
    sed -i 's/#rc_sys=""/rc_sys="lxc"/g' /etc/rc.conf &&\
    # Tell openrc loopback and net are already there, since docker handles the networking
    echo 'rc_provide="loopback net"' >> /etc/rc.conf &&\
    # no need for loggers
    sed -i 's/^#\(rc_logger="YES"\)$/\1/' /etc/rc.conf &&\
    # can't get ttys unless you run the container in privileged mode
    sed -i '/tty/d' /etc/inittab &&\
    # can't set hostname since docker sets it
    sed -i 's/hostname $opts/# hostname $opts/g' /etc/init.d/hostname &&\
    # can't mount tmpfs since not privileged
    sed -i 's/mount -t tmpfs/# mount -t tmpfs/g' /lib/rc/sh/init.sh &&\
    # can't do cgroups
    sed -i 's/cgroup_add_service /# cgroup_add_service /g' /lib/rc/sh/openrc-run.sh &&\
    # clean apk cache
    rm -rf /var/cache/apk/*

# Caching module installation 
COPY requirements.txt /
RUN pip install -r requirements.txt


COPY . /app
WORKDIR /app
RUN chmod +x /app/init_container.sh

EXPOSE 2222 5000

CMD env | sed -n "s/^\([^=]\+\)=\(.*\)$/export \1=\2/p"|sed 's/"/\\\"/g'|sed '/=/s//="/'|sed 's/$/"/'>>/etc/profile && source /etc/profile && /bin/bash /app/init_container.sh
