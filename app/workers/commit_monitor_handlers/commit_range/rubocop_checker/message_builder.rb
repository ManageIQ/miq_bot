require 'stringio'
require 'rubocop'
require 'haml_lint'

class CommitMonitorHandlers::CommitRange::RubocopChecker::MessageBuilder
  include BranchWorkerMixin

  def initialize(results, branch)
    @results = results
    @branch  = branch
  end

  def comments
    build_comments
    message_builder.comments
  end

  private

  attr_reader :results, :message_builder

  SUCCESS_EMOJI = %w{:+1: :cookie: :star: :cake:}

  SEVERITY = {
    "fatal"      => ":red_circle: **Fatal**",
    "error"      => ":red_circle: **Error**",
    "warning"    => ":red_circle: **Warn**",
    "convention" => ":large_orange_diamond:",
    "refactor"   => ":small_blue_diamond:",
  }.freeze

  COP_DOCUMENTATION_URI = File.join("http://rubydoc.info/gems/rubocop", RuboCop::Version.version)
  COP_URIS =
    RuboCop::Cop::Cop.subclasses.each_with_object({}) do |cop, h|
      cop_name_parts = cop.name.split("::")
      cop_name = cop_name_parts[2..-1].join("/")
      cop_uri  = File.join(COP_DOCUMENTATION_URI, cop_name_parts)
      h[cop_name] = "[#{cop_name}](#{cop_uri})"
    end.freeze

  def tag
    "<rubocop />"
  end

  def header
    header1 = "Checked #{"commit".pluralize(commits.length)} #{commit_range_text} with ruby #{RUBY_VERSION}, rubocop #{rubocop_version}, and haml-lint #{hamllint_version}"

    file_count    = results.fetch_path("summary", "target_file_count").to_i
    offense_count = results.fetch_path("summary", "offense_count").to_i
    header2 = "#{file_count} #{"file".pluralize(file_count)} checked, #{offense_count} #{"offense".pluralize(offense_count)} detected"

    "#{tag}#{header1}\n#{header2}"
  end

  def continuation_header
    "#{tag}**...continued**\n"
  end

  def build_comments
    @message_builder = MiqToolsServices::Github::MessageBuilder.new(header, continuation_header)
    files.empty? ? write_success : write_offenses
  end

  def write_success
    message_builder.write("Everything looks good. #{SUCCESS_EMOJI.sample}")
  end

  def write_offenses
    files.each do |f|
      message_builder.write("\n**#{f["path"]}**")
      message_builder.write_lines(offense_lines(f))
    end
  end

  def files
    results["files"].select { |f| f["offenses"].any? }.sort_by { |f| f["path"] }
  end

  def offense_lines(file)
    sorted_offense_records(file).collect do |o|
      "- [ ] %s - %s, %s - %s - %s" % [
        format_severity(o["severity"]),
        format_line(o["location"]["line"], file["path"]),
        format_column(o["location"]["column"]),
        format_cop_name(o["cop_name"]),
        o["message"]
      ]
    end
  end

  def sorted_offense_records(file)
    file["offenses"].sort_by do |o|
      [
        order_severity(o["severity"]),
        o["location"]["line"],
        o["location"]["column"],
        o["cop_name"]
      ]
    end
  end

  def order_severity(sev)
    SEVERITY.keys.index(sev) || Float::INFINITY
  end

  def format_severity(sev)
    SEVERITY[sev] || sev.capitalize[0, 5]
  end

  # TODO: Don't reuse the commit_uri.  This should probably be its own URI.
  def line_uri
    branch.commit_uri.chomp("commit/$commit")
  end

  def format_line(line, path)
    uri = File.join(line_uri, "blob", commits.last, path)
    "[Line #{line}](#{uri}#L#{line})"
  end

  def format_column(column)
    "Col #{column}"
  end

  def format_cop_name(cop_name)
    COP_URIS[cop_name] || cop_name
  end

  def rubocop_version
    RuboCop::Version.version
  end

  def hamllint_version
    HamlLint::VERSION
  end
end
