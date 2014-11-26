# Copy the postgres template yml to database.yml if it doesn't exist
db_yml = File.join(File.dirname(__FILE__), 'database.yml')
unless File.exists?(db_yml)
  db_template = File.join(File.dirname(__FILE__), 'database.tmpl.yml')
  require 'fileutils'
  FileUtils.cp(db_template, db_yml) if File.exists?(db_template)
end
