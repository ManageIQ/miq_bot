FROM registry.access.redhat.com/ubi8/ubi:latest
MAINTAINER ManageIQ https://manageiq.org

ARG REF=master

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

RUN curl -L -o /usr/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_x86_64 && \
    chmod +x /usr/bin/dumb-init

RUN dnf config-manager --setopt=ubi-8-*.exclude=net-snmp*,dracut*,libcom_err*,python3-gobject*,redhat-release* --save && \
    dnf -y --disableplugin=subscription-manager --setopt=tsflags=nodocs install \
      http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/Packages/centos-stream-repos-8-2.el8.noarch.rpm \
      http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/Packages/centos-gpg-keys-8-2.el8.noarch.rpm \
      https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    dnf -y --disableplugin=subscription-manager module enable nodejs:18 && \
    dnf -y --disableplugin=subscription-manager module enable ruby:2.7 && \
    dnf clean all && \
    rm -rf /var/cache/dnf

RUN dnf -y --disableplugin=subscription-manager --setopt=tsflags=nodocs install \
      @development \
      cmake \
      git \
      libcurl-devel \
      libffi-devel \
      libssh2-devel \
      libxml2-devel \
      openssl \
      openssl-devel \
      postgresql-devel \
      ruby \
      ruby-devel \
      shared-mime-info \
      sqlite-devel \
      yamllint && \
    dnf -y update libarchive && \
    # Clean up all the things
    dnf clean all && \
    rm -rf /var/cache/dnf && \
    rm -rf /var/lib/dnf/history* && \
    rm -rf /var/log/dnf*.log && \
    rm -rf /var/log/hawkey.log && \
    rm -rf /var/lib/rpm/__db.*

RUN mkdir -p $APP_ROOT && \
    curl -L https://github.com/ManageIQ/miq_bot/archive/$REF.tar.gz | tar xz -C $APP_ROOT --strip 1 && \
    chgrp -R 0 $APP_ROOT && \
    chmod -R g=u $APP_ROOT && \
    cp $APP_ROOT/container-assets/container_env /usr/local/bin && \
    cp $APP_ROOT/container-assets/entrypoint /usr/local/bin

WORKDIR $APP_ROOT

RUN echo "gem: --no-document" > ~/.gemrc && \
    gem install bundler && \
    bundle config set --local build.rugged --with-ssh && \
    bundle install --jobs=3 --retry=3 && \
    # Clean up all the things
    rm -rf /usr/share/gems/cache/* && \
    rm -rf /usr/share/gems/gems/rugged-*/vendor && \
    find /usr/share/gems/gems/ -name *.o -type f -delete && \
    find /usr/share/gems/gems/ -maxdepth 2 -name docs -type d -exec rm -r {} + && \
    find /usr/share/gems/gems/ -maxdepth 2 -name spec -type d -exec rm -r {} + && \
    find /usr/share/gems/gems/ -maxdepth 2 -name test -type d -exec rm -r {} +

ENTRYPOINT ["/usr/bin/dumb-init", "--single-child", "--"]

CMD ["entrypoint"]
