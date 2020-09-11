require 'pronto/runners'
require 'pronto/gem_names'
require 'pronto/git/repository'
require 'pronto/git/patches'
require 'pronto/git/patch'
require 'pronto/git/line'

require 'tempfile'

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
    generate_linter_configs

    git_service    = branch.git_service
    merge_base     = git_service.merge_base
    pronto_repo    = Pronto::Git::Repository.new(repo.path.to_s)
    pronto_patches = Pronto::Git::Patches.new(pronto_repo, merge_base, git_service.diff.raw_diff)

    Pronto::Runners.new.run(pronto_patches)
  end

  # configs in the repo itself most likely will be invalid as the what the
  # `MinigitService` has checked out in `.repos/` probably isn't the same SHA
  # as what we are working with.
  #
  # Any specifics per linter that need to be adjusted need to be done here, but
  # RuboCop might be the only one that is necessary for now.
  #
  def generate_linter_configs
    # Ensure any tempfiles created here are kept around through
    # `.run_all_linters`, and will be unlinked there.
    @config_tempfiles = []

    # This is config option found in the `proto-rubocop` plugin README:
    #
    #   > You can also specify a custom .rubocop.yml location with the
    #   > environment variable RUBOCOP_CONFIG.
    #
    git_service              = branch.git_service
    rubocop_config_contents  = git_service.content_at(".rubocop.yml")
    yamllint_config_contents = git_service.content_at(".yamllint")

    if rubocop_config_contents
      rubocop_yaml_data = YAML.load(rubocop_config_contents)
      (rubocop_yaml_data.delete("inherit_from") || []).each do |local_config_path|
        next unless inherit_from_data = git_service.content_at(local_config_path)

        rubocop_yaml_data["inherit_from"] ||= []
        rubocop_yaml_data["inherit_from"]  << generate_temp_config(local_config_path, inherit_from_data)
      end

      ENV["RUBOCOP_CONFIG"] = generate_temp_config(".rubocop.yml", rubocop_yaml_data.to_yaml)
    end

    if yamllint_config_contents
      yamllint_config_path  = generate_temp_config(".yamllint", yamllint_config_contents)
      ENV["YAMLLINT_OPTS"] = "-c #{yamllint_config_path}"
    end
  end

  def generate_temp_config(config_filepath, file_contents)
    temp_config = Tempfile.new(config_filepath)
    temp_config.write file_contents
    temp_config.close

    @config_tempfiles << temp_config

    temp_config.path
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
  ensure
    @config_tempfiles.each(&:unlink)
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
