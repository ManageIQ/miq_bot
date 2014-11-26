require 'stringio'
require 'rubocop'

class CommitMonitorHandlers::CommitRange::RubocopChecker::MessageBuilder
  attr_reader :messages

  def initialize(results, branch)
    @results  = results
    @branch   = branch
    @commits  = branch.commits_list

    @message  = StringIO.new
    @messages = [@message]

    build_messages
  end

  private

  attr_reader :results, :branch, :commits, :message

  GITHUB_COMMENT_BODY_MAX_SIZE = 65535
  SUCCESS_EMOJI = %w{:+1: :cookie: :star: :cake:}

  SEVERITY = {
    "fatal"      => "Fatal",
    "error"      => "Error",
    "warning"    => "Warn",
    "convention" => "Style",
    "refactor"   => "Refac",
  }.freeze

  COP_DOCUMENTATION_URI = File.join("http://rubydoc.info/gems/rubocop", Rubocop::Version.version)
  COP_URIS =
    Rubocop::Cop::Cop.subclasses.each_with_object({}) do |cop, h|
      cop_name = cop.name.split("::").last
      cop_uri  = File.join(COP_DOCUMENTATION_URI, cop.name.split("::"))
      h[cop_name] = "[#{cop_name}](#{cop_uri})"
    end.freeze

  def build_messages
    write_header
    files.empty? ? write_success : write_offenses
    @messages.collect! { |m| m.string }
  end

  def write(line)
    if message.length + line.length + 1 >= GITHUB_COMMENT_BODY_MAX_SIZE
      @message = StringIO.new
      @messages << message
      write_header_continued
    end

    message.puts(line)
  end

  def write_header
    commit_range = [
      branch.commit_uri_to(commits.first),
      branch.commit_uri_to(commits.last),
    ].uniq.join(" .. ")
    write("Checked #{"commit".pluralize(commits.length)} #{commit_range} with rubocop #{rubocop_version}")

    file_count    = results.fetch_path("summary", "target_file_count").to_i
    offense_count = results.fetch_path("summary", "offense_count").to_i
    write("#{file_count} #{"file".pluralize(file_count)} checked, #{offense_count} #{"offense".pluralize(offense_count)} detected")
  end

  def write_header_continued
    write("**...continued**\n")
  end

  def write_success
    write("Everything looks good. #{SUCCESS_EMOJI.sample}")
  end

  def write_offenses
    files.each do |f|
      write("\n**#{f["path"]}**")
      offense_messages(f).each { |line| write(line) }
    end
  end

  def files
    results["files"].select { |f| f["offenses"].any? }.sort_by { |f| f["path"] }
  end

  def offense_messages(file)
    sorted_offenses(file).collect do |o|
      "- [ ] %s - %s, %s - %s - %s" % [
        format_severity(o["severity"]),
        format_line(o["location"]["line"], file["path"]),
        format_column(o["location"]["column"]),
        format_cop_name(o["cop_name"]),
        o["message"]
      ]
    end
  end

  def sorted_offenses(file)
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
    Rubocop::Version.version
  end
end
