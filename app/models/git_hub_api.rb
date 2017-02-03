require 'benchmark'

module GitHubApi
  def self.execute(client, cmd, *args)
    limit_before = client.rate_limit.remaining
    logger.debug("Executing #{cmd} #{args.inspect}...api calls remaining #{limit_before}")
    val = nil
    t = Benchmark.realtime { val = client.send(cmd, *args) }
    limit_after = client.rate_limit.remaining
    logger.info("Executed #{cmd} #{args.inspect}...api calls remaining #{limit_after} " \
                "(in #{"%0.3f" % t}s using #{limit_before - limit_after} calls)")
    val
  rescue => err
    logger.error("Executed #{cmd} #{args.inspect}...Failed in #{"%0.3f" % t}s")
    logger.error("#{err.class}: #{err}")
    logger.error(err.backtrace.join("\n"))
    raise
  end

  def self.logger
    Sidekiq::Logging.logger
  end
end
