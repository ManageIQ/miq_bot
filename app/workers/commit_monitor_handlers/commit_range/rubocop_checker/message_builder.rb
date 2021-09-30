require 'rubocop'
require 'rubocop-rails'
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

  SUCCESS_EMOJI = %w{:+1: :cookie: :star: :cake: :trophy:}

  SEVERITY_MAP = Hash.new(:unknown).merge(
    "fatal"      => :error,
    "error"      => :error,
    "warning"    => :warn,
    "convention" => :high,
    "refactor"   => :low,
  ).freeze

  COP_URIS = RuboCop::Cop::Base.descendants.each_with_object({}) do |cop, h|
    plugin, version = nil

    case cop.department
    when :Rails
      plugin  = "rubocop-rails"
      version = RuboCop::Rails::Version.document_version
    else
      plugin  = "rubocop"
      version = RuboCop::Version.document_version
    end

    url               = URI(RuboCop::Cop::Documentation.url_for(cop))
    url_path_parts    = url.path.split("/")
    url_path_parts[1] = plugin
    url_path_parts.insert(2, version) unless url_path_parts[2] == version

    url.path        = url_path_parts.join("/")
    h[cop.cop_name] = "[#{cop.cop_name}](#{url})"
  end.freeze

  def tag
    "<rubocop />"
  end

  def header
    header1 = "Checked #{"commit".pluralize(commits.length)} #{commit_range_text} with ruby #{RUBY_VERSION}, rubocop #{rubocop_version}, haml-lint #{hamllint_version}, and yamllint #{yamllint_version}"

    file_count    = results.fetch_path("summary", "target_file_count").to_i
    offense_count = results.fetch_path("summary", "offense_count").to_i
    header2 = "#{file_count} #{"file".pluralize(file_count)} checked, #{offense_count} #{"offense".pluralize(offense_count)} detected"

    "#{tag}#{header1}\n#{header2}"
  end

  def continuation_header
    "#{tag}**...continued**\n"
  end

  def build_comments
    @message_builder = GithubService::MessageBuilder.new(header, continuation_header)
    files.empty? ? write_success : write_offenses
  end

  def write_success
    message_builder.write("Everything looks fine. #{SUCCESS_EMOJI.sample}")
  end

  def write_offenses
    content = OffenseMessage.new
    content.entries = offenses
    message_builder.write("")
    message_builder.write_lines(content.lines)
  end

  def offenses
    files.collect do |f|
      f["offenses"].collect do |o|
        OffenseMessage::Entry.new(
          SEVERITY_MAP[o["severity"]],
          format_message(o),
          f["path"],
          format_locator(f, o)
        )
      end
    end.flatten
  end

  def files
    results["files"].select { |f| f["offenses"].any? }
  end

  def format_message(offense)
    [format_cop_name(offense["cop_name"]), offense["message"]].compact.join(" - ")
  end

  def format_cop_name(cop_name)
    COP_URIS[cop_name] || cop_name
  end

  def format_locator(file, offense)
    [format_line(file, offense), format_column(offense)].compact.join(", ").presence
  end

  def format_line(file, offense)
    line = offense.fetch_path("location", "line")
    return nil unless line
    uri = File.join(line_uri, "blob", commits.last, file["path"]) << "#L#{line}"
    "[Line #{line}](#{uri})"
  end

  def format_column(offense)
    column = offense.fetch_path("location", "column")
    column && "Col #{column}"
  end

  # TODO: Don't reuse the commit_uri.  This should probably be its own URI.
  def line_uri
    branch.commit_uri.chomp("commit/$commit")
  end

  def rubocop_version
    RuboCop::Version.version
  end

  def hamllint_version
    HamlLint::VERSION
  end

  def yamllint_version
    _out, err, _ps = Open3.capture3("yamllint -v")
    err.split.last
  end
end
