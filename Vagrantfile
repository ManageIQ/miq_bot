# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "fedora/29-cloud-base"

  # Otherwise the OOM killer will kill some of the install processes like dnf
  config.vm.provider :virtualbox do |vb|
    vb.memory = 1024
  end

  ssh_key_file = ENV["SSH_KEY_FOR_MIQ_BOT"] || File.join(Dir.home, ".ssh", "id_rsa")
  if File.exist?(ssh_key_file)
    config.vm.provision "file", :source      => ssh_key_file,
                                :destination => "/home/vagrant/id_rsa"
  end

  config.vm.provision "shell", inline: <<-SHELL.gsub(/^ {4}/, '')
    dnf install -y automake bison zlib-devel libyaml-devel openssl-devel           \
                   gdbm-devel readline-devel ncurses-devel libffi-devel            \
                   make patch gcc gcc-c++ cmake libssh2-devel ruby-devel rpm-build \
                   nodejs python-pip postgresql postgresql-server postgresql-devel

    pip install yamllint

    cd /vagrant
    gem install bundler:1.17.3
    bundle

    postgresql-setup --initdb --unit postgresql

    cat << EOF > /var/lib/pgsql/data/pg_hba.conf
    # TYPE  DATABASE    USER  ADDRESS METHOD
    local   all         all           peer map=usermap
    hostssl all         all   all     md5
    EOF

    cat << EOF > /var/lib/pgsql/data/pg_ident.conf
    # MAPNAME       SYSTEM-USERNAME         PG-USERNAME
    # users can login as themselves
    usermap         /^(.*)$                 \\1
    usermap         root                    postgres
    usermap         postgres                root
    EOF

    systemctl enable postgresql
    systemctl start postgresql

    su postgres -c "psql -c \\"CREATE ROLE root WITH LOGIN CREATEDB SUPERUSER PASSWORD 'smartvm'\\" postgres"

    cp /vagrant/config/database.vagrant.yml /vagrant/config/database.yml
    bundle exec rake db:setup

    cp /vagrant/systemd/* /etc/systemd/system/
    systemctl daemon-reload
  SHELL
end
