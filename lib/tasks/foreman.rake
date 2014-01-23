namespace :foreman do
  desc "Export upstart tasks"
  task :export do
    puts `foreman export upstart /etc/init -l #{Dir.pwd}/log/foreman -a cfme_bot -u root -p 3002 -e .production_env`
  end
end
