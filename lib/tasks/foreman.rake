namespace :foreman do
  desc "Export upstart tasks"
  task :export do
    puts `source ./.production_env && foreman export upstart /etc/init -l #{Dir.pwd}/log/foreman -a #{File.basename(Dir.pwd)} -u root -p $START_PORT -e .production_env`
  end
end
