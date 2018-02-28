require 'pronto/runners'
require 'pronto/rubocop'
require 'pronto/yamllint'
require 'pronto/haml'
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
      %w(offense_count target_file_count).each do |m|
        results['summary'][m] += result['summary'][m]
      end
      results['files'] += result['files']
    end

    results
  end

  # run linters via pronto and return the pronto result
  def pronto_result
    p_result = nil

    # temporary solution for: download repo, obtain changes, get pronto result about changes
    Dir.mktmpdir do |dir|
      FileUtils.copy_entry(@branch.repo.path.to_s, dir)
      repo = Pronto::Git::Repository.new(dir)
      rg = repo.instance_variable_get(:@repo)
      rg.fetch('origin', @branch.name.sub(/^prs/, 'pull'))
      rg.checkout('FETCH_HEAD')
      rg.reset('HEAD', :hard)
      patches = repo.diff(@branch.merge_target)
      p_result = Pronto::Runners.new.run(patches)
    end

    p_result
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
  end
end
