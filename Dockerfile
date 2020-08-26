FROM registry.access.redhat.com/ubi8/ubi:8.2
MAINTAINER ManageIQ https://manageiq.org

ARG REF=v0.11

ENV TERM=xterm \
    APP_ROOT=/opt/miq_bot

LABEL name="miq-bot" \
      vendor="ManageIQ" \
      url="https://manageiq.org/" \
      summary="ManageIQ Bot application image" \
      description="ManageIQ Bot is a developer automation tool." \
      io.k8s.display-name="ManageIQ Bot" \
      io.k8s.description="ManageIQ Bot is a developer automation tool." \
      io.openshift.tags="ManageIQ,miq-bot"

RUN dnf -y --disableplugin=subscription-manager install \
      unzip \
      wget \
      http://mirror.centos.org/centos/8.2.2004/BaseOS/x86_64/os/Packages/centos-repos-8.2-2.2004.0.1.el8.x86_64.rpm \
      http://mirror.centos.org/centos/8.2.2004/BaseOS/x86_64/os/Packages/centos-gpg-keys-8.2-2.2004.0.1.el8.noarch.rpm \
      https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    dnf -y --disableplugin=subscription-manager module enable nodejs:12 && \
    dnf -y --disableplugin=subscription-manager module enable ruby:2.6 && \
    dnf -y --disableplugin=subscription-manager upgrade && \
    dnf clean all

RUN wget https://github.com/ManageIQ/miq_bot/archive/$REF.zip && \
    unzip $REF.zip -d /opt && \
    rm -rf $REF.zip && \
    mv /opt/miq_bot-* $APP_ROOT && \
    chgrp -R 0 $APP_ROOT && \
    chmod -R g=u $APP_ROOT

RUN dnf -y --disableplugin=subscription-manager --setopt=tsflags=nodocs install \
      @development \
      cmake \
      git \
      libcurl-devel \
      libffi-devel \
      libxml2-devel \
      openssl \
      openssl-devel \
      postgresql-devel \
      python38 \
      ruby \
      ruby-devel \
      sqlite-devel \
      yamllint && \
    gem install bundler -v 1.17.3 && \
    cd $APP_ROOT && \
    bundle install

WORKDIR /opt/$APP_ROOT

RUN curl -L -o /usr/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_x86_64 && \
    chmod +x /usr/bin/dumb-init

COPY container-assets/container_env /usr/local/bin
COPY container-assets/entrypoint /usr/local/bin

ENTRYPOINT ["/usr/bin/dumb-init", "--single-child", "--"]

CMD ["entrypoint"]
