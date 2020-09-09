require 'pronto/runners'
require 'pronto/gem_names'
require 'pronto/git/repository'
require 'pronto/git/patches'
require 'pronto/git/patch'
require 'pronto/git/line'

require 'fileutils'
require 'tmpdir'

module CodeAnalysisMixin
  def merged_linter_results
    results = {
      "files"   => [],
      "summary" => {
        "offense_count"     => 0,
        "target_file_count" => 0,
      },
    }

    run_all_linters.each do |result|
      %w[offense_count target_file_count].each do |m|
        results['summary'][m] += result['summary'][m]
      end
      results['files'] += result['files']
    end

    results
  end

  # run linters via pronto and return the pronto result
  def pronto_result
    Pronto::GemNames.new.to_a.each { |gem_name| require "pronto/#{gem_name}" }

    branch.repo.git_fetch

    git_service    = branch.git_service
    merge_base     = git_service.merge_base
    pronto_repo    = Pronto::Git::Repository.new(repo.path.to_s)
    pronto_patches = Pronto::Git::Patches.new(pronto_repo, merge_base, git_service.diff.raw_diff)

    Pronto::Runners.new.run(pronto_patches)
  end

  def run_all_linters
    pronto_result.group_by(&:runner).values.map do |linted| # group by linter
      output = {}

      output["files"] = linted.group_by(&:path).map do |path, value| # group by file in linter
        {
          "path"     => path,
          "offenses" => value.map do |msg| # put offenses of file in linter into an array
            {
              "severity"  => msg.level.to_s,
              "message"   => msg.msg,
              "cop_name"  => msg.runner,
              "corrected" => false,
              "line"      => msg.line.position
            }
          end
        }
      end

      output["summary"] = {
        "offense_count"     => output["files"].sum { |item| item['offenses'].length },
        "target_file_count" => output["files"].length,
      }

      output
    end
  rescue RuboCop::ValidationError => error
    [failed_linter_offenses("#{self.class.name} STDERR:\n```\n#{error.message}\n```")]
  end

  def failed_linter_offenses(message)
    git_service   = branch.git_service
    files_to_lint = branch.pull_request? ? git_service.diff.new_files : git_service.tip_files
    {
      "files" => [
        {
          "path"     => "\\*\\*",
          "offenses" => [
            {
              "severity" => "fatal",
              "message"  => message,
              "cop_name" => self.class.name.titleize
            }
          ]
        }
      ],
      "summary" => {
        "offense_count"        => 1,
        "target_file_count"    => files_to_lint.length,
        "inspected_file_count" => files_to_lint.length
      }
    }
  end
end
