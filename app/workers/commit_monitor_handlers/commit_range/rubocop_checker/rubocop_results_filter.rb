module CommitMonitorHandlers
  module CommitRange
    class RubocopChecker
      class RubocopResultsFilter
        attr_reader :filtered

        def initialize(results, diff_details)
          @results      = results
          @diff_details = diff_details
          @filtered     = filter_rubocop_results
        end

        private

        def filter_rubocop_results
          @results["files"].each do |f|
            f["offenses"].select! do |o|
              o["severity"].in?(%w(error fatal)) ||
                @diff_details[f["path"]].include?(o["location"]["line"])
            end
          end

          @results["summary"]["offense_count"] =
            @results["files"].inject(0) { |sum, f| sum + f["offenses"].length }

          @results
        end
      end
    end
  end
end
