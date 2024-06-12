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

  def self.edit_secret(name)
    system("kubectl edit secret #{name}")
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

# rubocop:disable Style/StderrPuts

namespace :production do
  desc "Set the local kubernetes context to the production context"
  task :set_context do # rubocop:disable Rails/RakeEnvironment
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
    exit 1 unless Kubernetes.edit_secret("config")

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
    version
  end

  desc "Release a new version to production"
  task :release, [:version, :remote] do |_t, args|
    version = release_version(args[:version])
    remote  = args[:remote] || "upstream"

    puts "Ensuring version number..."
    unless File.readlines("templates/bot.yaml").grep(/image: .+miq_bot:v/).all? { |l| l.include?("miq_bot:#{version}") }
      $stderr.puts "ERROR: images in templates/bot.yaml have not been updated to the expected version"
      exit 1
    end

    puts "Deploying version #{version}..."

    puts
    puts "Tagging repository..."
    if `git tag --list #{version}`.chomp.empty?
      exit 1 unless system("git tag #{version}")
    elsif `git tag --points-at HEAD`.chomp != version
      $stderr.puts "ERROR: Already tagged '#{version}', but you are not on that commit"
      exit 1
    else
      puts "Already tagged '#{version}'"
    end
    exit 1 unless system("git push #{remote} #{version}")
  end

  namespace :release do
    desc "Build the specified version and push to docker.io"
    task :build, [:version] do |_t, args|
      version = release_version(args[:version])
      image   = "docker.io/manageiq/miq_bot:#{version}"

      puts "Building docker image..."
      exit 1 unless system("docker build . --no-cache --build-arg REF=#{version} -t #{image}")
      puts
      puts "Pushing docker image..."
      exit 1 unless system("docker login docker.io") && system("docker push #{image}")
      puts
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

# rubocop:enable Style/StderrPuts
