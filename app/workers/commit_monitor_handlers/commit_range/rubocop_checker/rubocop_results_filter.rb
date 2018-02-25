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
          filter_on_diff
          filter_void_warnings_in_spec_files

          @results["summary"]["offense_count"] =
            @results["files"].inject(0) { |sum, f| sum + f["offenses"].length }

          @results
        end

        def filter_on_diff
          @results["files"].each do |f|
            f["offenses"].select! do |o|
              o["severity"].in?(%w(error fatal)) ||
                @diff_details[f["path"]].include?(o["line"])
            end
          end
        end

        def filter_void_warnings_in_spec_files
          @results["files"].each do |f|
            next unless f["path"].match %r{(?:^|/)spec/.+_spec.rb}

            f["offenses"].reject! do |o|
              o["cop_name"].in?(%w(Void Lint/Void))
            end
          end
        end
      end
    end
  end
end
