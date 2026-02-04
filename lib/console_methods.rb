module ConsoleMethods
  def simulate_sidekiq(*queue_names, run_once: false)
    run = true
    while run
      queue_names.each do |queue_name|
        puts "[#{Time.now}] Processing '#{queue_name}'..."
        Sidekiq::Queue.new(queue_name).each do |job|
          worker = job['class'].constantize
          args = job['args']
          puts "\nProcessing #{worker} with args: #{args}"
          worker.new.perform(*job['args'])
          job.delete
        end
      end
      run = false if run_once
      sleep(2)
    end
  end
end
