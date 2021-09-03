module Kubernetes
  def self.available?
    !`which kubectl`.chomp.empty?
  end

  def self.config_dir
    @config_dir ||= Pathname.new("~/.kube").expand_path
  end

  def self.config_file
    @config_file ||= config_dir.join("config")
  end

  def self.merge_config(file)
    system({"KUBECONFIG" => "#{config_file}:#{file}"}, "kubectl config view --flatten > #{config_file}")
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

  def self.edit_config_map(name)
    system("kubectl edit configmap #{name}")
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

# rubocop:disable Style/StderrPuts

namespace :production do
  desc "Set the local kubernetes context to the production context"
  task :set_context do # rubocop:disable Rails/RakeEnvironment
    context   = "do-nyc1-miq-prod"
    name      = "miq-prod"
    namespace = "bot"

    unless Kubernetes.available?
      $stderr.puts "ERROR: You must install kubectl command"
      exit 1
    end

    unless Kubernetes.context?(context)
      puts "Configuring Kubernetes context..."

      config = Kubernetes.config_dir.join("#{name}-kubeconfig.yaml")
      unless config.exist?
        $stderr.puts
        $stderr.puts "ERROR: Cannot find the context config file"
        $stderr.puts
        $stderr.puts "1. Go to digitalocean.com => Kubernetes => #{name} => Download Config File"
        $stderr.puts "2. Place the file in #{Kubernetes.config_dir}"
        exit 1
      end

      Kubernetes.merge_config(config)
      config.delete

      puts "Configuring Kubernetes context...Complete"
    end

    exit 1 unless Kubernetes.use_context(context) && Kubernetes.use_namespace(namespace)
    puts
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

  desc "Edit the bot settings in production"
  task :edit_settings => :set_context do
    exit 1 unless Kubernetes.edit_config_map("bot-settings")

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
end

desc "Release a new version to production"
task :release, [:version, :remote] => "production:set_context" do |_t, args|
  version = args[:version]
  if version.nil?
    $stderr.puts "ERROR: must specify the version number to deploy"
    exit 1
  end
  version = "v#{version}" unless version.start_with?("v")

  remote = args[:remote] || "upstream"

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

  image = "docker.io/manageiq/miq_bot:#{version}"

  puts
  puts "Building docker image..."
  exit 1 unless system("docker build . --no-cache -t #{image}")
  puts
  puts "Pushing docker image..."
  exit 1 unless system("docker login") && system("docker push #{image}")
  puts

  puts "Updating queue-worker deployment..."
  exit 1 unless Kubernetes.update_deployment_image("queue-worker", image)
  puts "Updating ui deployment..."
  exit 1 unless Kubernetes.update_deployment_image("ui", image)

  puts
  puts "Deploying version #{version}...Complete"
end

# rubocop:enable Style/StderrPuts
