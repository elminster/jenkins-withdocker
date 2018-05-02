FROM jenkins/jenkins:lts
# Based on Jenkins Dockerfile from getintodevops/jenkins-withdocker
LABEL maintainer="duncan@elminster.com"

# Switch to root user
USER root

#Build arguments
ARG GOSU_VERSION=1.10
ARG mailname="jenkins_master"
ARG relayhost="[smtp.myisp.com]:465"
ARG rootaddr="fred@blah.com"
ARG ISPusername="myusername@myisp.com"
ARG ISPpwd="123456789"
ARG fromaddr="$ISPusername"

# Added for postfix silent install config
RUN echo "postfix postfix/mailname string $mailname" | debconf-set-selections
RUN echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections
RUN echo "postfix postfix/relayhost string $relayhost" | debconf-set-selections
RUN echo "postfix postfix/root_address string rootaddr" | debconf-set-selections


# Update packages, Install the latest Docker CE & posfix binaries, Cleanup
RUN apt-get update && apt-get -y upgrade && \
    apt-get -y install apt-transport-https \
      ca-certificates \
      curl wget \
      gnupg2 \
      software-properties-common && \
    curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg > /tmp/dkey; apt-key add /tmp/dkey && \
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NFF }')" && \
    add-apt-repository \
      "deb [arch=${dpkgArch}] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
      $(lsb_release -cs) \
      stable" && \
    apt-get update && \
    apt-get -y install docker-ce \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" \
    && chmod +x /usr/local/bin/gosu \
    && DEBIAN_FRONTEND=noninteractive apt-get -y install postfix  libsasl2-modules --no-install-recommends \
    && apt-get -y install syslog-ng vim \
	&& apt-get purge -y --autoremove wget \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /etc/postfix

# Configure postfix to relay emails to a relay server e.g. your iSP
COPY add_to_postfix.txt .
RUN echo "$relayhost ${ISPusername}:${ISPpwd}" > /etc/postfix/sasl_passwd \
    && echo "@${mailname} $fromaddr" > /etc/postfix/generic \
    && echo "root@${mailname} $fromaddr" > /etc/postfix/generic \
    && postmap /etc/postfix/sasl_passwd && postmap /etc/postfix/generic \
    && chown root:root /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db \
    && chmod 0600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db \
    && chown root:root /etc/postfix/generic /etc/postfix/generic.db \
    && chmod 0600 /etc/postfix/generic /etc/postfix/generic.db \
    && cat add_to_postfix.txt >> /etc/postfix/main.cf \
    && echo "$mailname" > /etc/mailname

WORKDIR /

# Convert to Puppet style daemon entry point (with extra user parameter)
# Configure entrypoint
COPY /docker-entrypoint.sh /
COPY /docker-entrypoint.d/* /docker-entrypoint.d/
RUN chmod a+x /docker-entrypoint.sh /docker-entrypoint.d/*

# Fix for jenkins access to /var/run/docker using docker-compose on Mac issue
RUN gpasswd -a jenkins staff

# Fix for jenkins access to /var/run/docker
#RUN sudo groupadd -g 996 docker
RUN sudo usermod -aG docker jenkins

# Run jenkins after running scirpts in docker-entrypoint directory
# Everything runs in docker-entrypoint.d as root or last USER directive (gosu can be used in scripts)
# docker-entrypoint.sh usage: <user> <script> 
ENTRYPOINT ["/docker-entrypoint.sh", "jenkins","/sbin/tini","--","/usr/local/bin/jenkins.sh"]

