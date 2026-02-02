module Kubernetes
  def self.available?
    !`which kubectl`.chomp.empty?
  end

  def self.context?(context)
    !`kubectl config get-contexts --no-headers #{context} 2>/dev/null`.chomp.empty?
  end

  def self.current_namespace
    `kubectl config view --minify --output jsonpath={.contexts..namespace}`.chomp
  end

  def self.use_context(context)
    system("kubectl config use-context #{context}")
  end

  def self.use_namespace(namespace)
    current_namespace == namespace || system("kubectl config set-context --current --namespace=#{namespace}")
  end

  def self.pod_from_deployment(deployment)
    `kubectl get pods -l name=#{deployment} --output jsonpath={.items..metadata.name}`.chomp
  end

  def self.pod_from_container(container)
    `kubectl get pods -o json | jq -r '.items[] | select(.spec.containers[].name == "#{container}") | .metadata.name'`.chomp
  end

  def self.restart_deployment_pods(deployment)
    system("kubectl delete pod #{pod_from_deployment(deployment)}")
  end

  def self.console(deployment, cmd = "/bin/bash")
    system("kubectl exec --stdin --tty #{pod_from_deployment(deployment)} -- #{cmd}")
  end

  def self.tail_log(container)
    system("kubectl logs -f #{pod_from_container(container)} #{container}")
  rescue Interrupt
    true
  end

  def self.update_deployment_image(deployment, image)
    system("kubectl get deployment #{deployment} -o json | jq '.spec.template.spec.containers[].image = \"#{image}\"' | kubectl replace -f -")
  end
end

module IbmCloud
  def self.available?
    !`which ibmcloud`.chomp.empty?
  end

  def self.plugin_available?(plugin)
    `ibmcloud plugin list --output json | jq -r .[].Name`.lines(chomp: true).include?(plugin)
  end

  def self.ks_plugin_available?
    plugin_available?("container-service")
  end

  def self.api_key
    ENV["IBMCLOUD_BOT_API_KEY"]
  end

  def self.logged_in_as
    `ibmcloud target --output json | jq -r .user.user_email`.chomp
  end

  def self.logged_in?
    logged_in_as.start_with?("imbot")
  end

  def self.login
    return false unless api_key

    system({"IBMCLOUD_API_KEY" => api_key}, "ibmcloud login -r us-east -g manageiq", [:out, :err] => "/dev/null")
  end

  def self.ks_cluster_config(cluster_name)
    system("ibmcloud ks cluster config --cluster #{cluster_name}", [:out, :err] => "/dev/null")
  end
end

# rubocop:disable Rails/RakeEnvironment, Style/StderrPuts

module Helpers
  def self.edit_github_password(secret_name, settings_key)
    require 'base64'
    require 'tempfile'
    require 'yaml'

    secret_yaml = `kubectl get secret #{secret_name} -o yaml`
    return false unless $?.success?

    # Extract the github_credentials/password field from the secret
    secret_data = YAML.safe_load(secret_yaml)

    encoded_settings = secret_data.dig("data", settings_key)
    unless encoded_settings
      $stderr.puts "ERROR: Key '#{settings_key}' not found in secret '#{secret_name}'"
      return false
    end

    decoded_settings = Base64.decode64(encoded_settings)
    settings_yaml = YAML.safe_load(decoded_settings)

    old_password = settings_yaml.dig("github_credentials", "password")
    unless old_password
      $stderr.puts "ERROR: github_credentials/password not found in '#{settings_key}'"
      return false
    end

    # Edit the password in a temporary file
    new_password = nil
    Tempfile.create(['github_credentials-password-', '.txt'], mode: 0600) do |tempfile|
      tempfile.write(old_password)
      tempfile.close

      # Open in editor
      editor = ENV.fetch('EDITOR', 'vi')
      unless system("#{editor} #{tempfile.path}")
        $stderr.puts "ERROR: Failed to run editor '#{editor}'"
        return false
      end

      new_password = File.read(tempfile.path).strip
    end

    if new_password.empty?
      $stderr.puts "ERROR: Password cannot be blank"
      return false
    end

    # Check if password changed and update if needed
    if new_password != old_password
      puts "Password has changed. Updating secret..."

      settings_yaml["github_credentials"]["password"] = new_password

      new_settings_yaml = YAML.dump(settings_yaml)
      secret_data["data"][settings_key] = Base64.strict_encode64(new_settings_yaml)

      # Write to temporary file for kubectl replace
      Tempfile.create(['secret-', '.yaml']) do |secret_file|
        secret_file.write(YAML.dump(secret_data))
        secret_file.close

        # Replace the updated secret
        unless system("kubectl replace -f #{secret_file.path}")
          $stderr.puts "ERROR: Failed to replace updated secret"
          return false
        end
        puts "Secret updated successfully!"
      end
    else
      puts "Password unchanged. No update needed."
    end

    true
  end
end

namespace :production do
  desc "Set the local kubernetes context to the production context"
  task :set_context do
    cluster_name = "miq-cluster-us-east-2"
    cluster_id   = "cgm83c8w0she4h8kofeg"
    context      = "#{cluster_name}/#{cluster_id}"
    namespace    = "bot"

    raise "kubectl command not installed" unless Kubernetes.available?
    raise "ibmcloud command not installed" unless IbmCloud.available?
    raise "ibmcloud container-service plugin not installed" unless IbmCloud.ks_plugin_available?
    raise "Unable to login with ibmcloud command" unless IbmCloud.logged_in? || (IbmCloud.login && IbmCloud.logged_in?)
    raise "Unable to configure the kubernetes cluster for ibmcloud command" unless IbmCloud.ks_cluster_config(cluster_name)
    raise "Kubernetes context does not exist" unless Kubernetes.context?(context)
    raise "Kubernetes context is invalid" unless Kubernetes.use_context(context)
    raise "Unable to set kubernetes namespace" unless Kubernetes.use_namespace(namespace)
  rescue => e
    $stderr.puts "ERROR: #{e.message}"
    exit 1
  end

  desc "Restart all production pods"
  task :restart => :set_context do
    puts "Restarting the queue-worker pod..."
    exit 1 unless Kubernetes.restart_deployment_pods("queue-worker")
    puts "Restarting the queue-worker pod...Complete"

    puts "Restarting the ui pod..."
    exit 1 unless Kubernetes.restart_deployment_pods("ui")
    puts "Restarting the ui pod...Complete"
  end

  desc "Edit the bot token in production"
  task :edit_token => :set_context do
    exit 1 unless Helpers.edit_github_password("config", "settings.local.yml")

    puts "Restarting the queue-worker pod..."
    exit 1 unless Kubernetes.restart_deployment_pods("queue-worker")
    puts "Restarting the queue-worker pod...Complete"
  end

  desc "Open a console in production (deployment defaults to 'queue-worker')"
  task :console, [:deployment] => :set_context do |_t, args|
    deployment = args[:deployment] || "queue-worker"
    exit 1 unless Kubernetes.console(deployment, "/bin/bash -c \"source container-assets/container_env; bash\"")
  end

  desc "Tail container logs in production (container defaults to 'queue-worker')"
  task :logs, [:container] => :set_context do |_t, args|
    container = args[:container] || "queue-worker"
    exit 1 unless Kubernetes.tail_log(container)
  end

  def release_version(version)
    if version.nil?
      $stderr.puts "ERROR: must specify the version number to deploy"
      exit 1
    end

    version = "v#{version}" unless version.start_with?("v")
    unless version.match?(/^v\d+\.\d+\.\d+$/)
      $stderr.puts "ERROR: version is not in the expected format"
      exit 1
    end

    version
  end

  desc "Release a new version to production"
  task :release, [:version, :remote] do |_t, args|
    version = release_version(args[:version])
    remote  = args[:remote] || "upstream"

    puts "Deploying version #{version}..."

    puts
    puts "Ensuring version number..."
    # Modify the versions
    content = File.read("config/application.rb")
    content.sub!(/(?<=VERSION = ")\d+\.\d+\.\d+/, version[1..])
    File.write("config/application.rb", content)
    content = File.read("templates/bot.yaml")
    content.gsub!(/(image: .+miq_bot:)v\d+\.\d+\.\d+/, "\\1#{version}")
    File.write("templates/bot.yaml", content)

    # Commit the changes
    unless system("git diff --quiet config/application.rb templates/bot.yaml")
      exit 1 unless system("git add config/application.rb templates/bot.yaml && git commit -m 'Release #{version}'")
    end

    # Double check the versions
    unless File.read("config/application.rb").include?("VERSION = \"#{version[1..]}\".freeze")
      $stderr.puts "ERROR: config/application.rb has not been updated to the expected version"
      exit 1
    end
    unless File.readlines("templates/bot.yaml").grep(/image: .+miq_bot:v/).all? { |l| l.include?("miq_bot:#{version}") }
      $stderr.puts "ERROR: images in templates/bot.yaml have not been updated to the expected version"
      exit 1
    end

    puts
    puts "Tagging repository..."
    if `git tag --list #{version}`.chomp.empty?
      exit 1 unless system("git tag #{version} -m 'Release #{version}'")
    elsif `git tag --points-at HEAD`.chomp != version
      $stderr.puts "ERROR: Already tagged '#{version}', but you are not on that commit"
      exit 1
    else
      puts "Already tagged '#{version}'"
    end
    if ENV.fetch("DRY_RUN", false)
      puts "** dry-run: git push #{remote} #{version} master"
    else
      exit 1 unless system("git push #{remote} #{version} master")
    end
  end

  namespace :release do
    desc "Build the specified version and push to docker.io"
    task :build, [:version] do |_t, args|
      version = release_version(args[:version])
      image   = "docker.io/manageiq/miq_bot:#{version}"

      puts "Asserting that the source is on the tagged version..."
      unless `git tag --points-at HEAD`.chomp == version
        $stderr.puts "ERROR: Source is not on the tagged version '#{version}'."
        exit 1
      end
      puts "Asserting that the source has no changes from the tagged version..."
      unless `git status --porcelain`.chomp.empty?
        $stderr.puts "ERROR: Source has local changes from the tagged version."
        exit 1
      end

      puts
      puts "Building docker image..."
      exit 1 unless system("docker build . --platform=linux/amd64 --no-cache -t #{image}")
      puts
      puts "Pushing docker image..."
      if ENV.fetch("DRY_RUN", false)
        puts "** dry-run: docker login docker.io && docker push #{image}"
      else
        exit 1 unless system("docker login docker.io") && system("docker push #{image}")
      end
    end

    desc "Deploy the specified version to Kubernetes"
    task :deploy, [:version] => "production:set_context" do |_t, args|
      version = release_version(args[:version])
      image   = "docker.io/manageiq/miq_bot:#{version}"

      puts "Updating queue-worker deployment..."
      exit 1 unless Kubernetes.update_deployment_image("queue-worker", image)
      puts "Updating ui deployment..."
      exit 1 unless Kubernetes.update_deployment_image("ui", image)

      puts
      puts "Deploying version #{version}...Complete"
    end
  end
end

desc "Release a new version to production (alias of production:release)"
task :release, [:version, :remote] do |_t, args|
  Rake::Task["production:release"].invoke(*args)
end

# rubocop:enable Rails/RakeEnvironment, Style/StderrPuts
