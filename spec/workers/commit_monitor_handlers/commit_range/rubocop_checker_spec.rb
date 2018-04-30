require 'spec_helper'

RSpec.describe CommitMonitorHandlers::CommitRange::RubocopChecker do
  subject { described_class.new }

  describe "#run" do
    let(:comment_body) { "Comment body." }
    let(:comments) { ["Version table. + Comment body."] }

    it "launches the linter checking process" do
      expect(subject).to receive(:pronto_result).and_return([]).once
      expect(subject).to receive(:pronto_format).with([]).and_return(comment_body).once
      expect(subject).to receive(:create_comment).with(comment_body).and_return(comments).once
      expect(subject).to receive(:replace_pronto_comments).with(comments).once
      subject.send(:run)
    end
  end

  describe "#create_comment" do
    let(:tag) { "<pronto />" }
    let(:body) { "Comment body." }
    let(:table) { "Version table." }
    let(:commits) { double("Branch", :length => 42) }
    let(:commit_range) { "owner/repo@0000000~...fffffff" }
    let(:comment) { "<pronto />Commits owner/repo@0000000~...fffffff checked with ruby #{RUBY_VERSION} and:\n\nVersion table.\n\nComment body." }

    it "creates comment" do
      expect(subject).to receive(:pronto_tag).and_return(tag).once
      expect(subject).to receive(:versions_table).and_return(table).once
      expect(subject).to receive(:commits).and_return(commits).once
      expect(subject).to receive(:commit_range_text).and_return(commit_range).once
      expect(subject.send(:create_comment, body)).to eq([comment])
    end
  end

  describe "#replace_pronto_comments" do
    let(:logger) { double("Logger") }
    let(:pronto_comments) { ["Pronto Comment"] }

    it "replaces old pull request comments with new one" do
      expect(subject).to receive(:fq_repo_name).and_return("owner/repo").twice
      expect(subject).to receive(:pr_number).and_return(42).twice
      expect(subject).to receive(:logger).and_return(logger).once
      expect(logger).to receive(:info).with("Updating https://github.com/owner/repo/pull/42 with Pronto comment.").once
      expect(GithubService).to receive(:replace_comments).with("owner/repo", 42, pronto_comments).once

      subject.send(:replace_pronto_comments, pronto_comments)
    end
  end

  describe "#pronto_tag" do
    it "returns tag" do
      expect(subject.send(:pronto_tag)).to eq("<pronto />")
    end
  end

  describe "#pronto_comment?" do
    let(:comment_true) { double("Comment", :body => "<pronto />Comment body.") }
    let(:comment_false) { double("Comment", :body => "Comment body.") }

    it "returns true" do
      expect(subject.send(:pronto_comment?, comment_true)).to eq(true)
    end

    it "returns false" do
      expect(subject.send(:pronto_comment?, comment_false)).to eq(false)
    end
  end

  describe "#versions_table" do
    let(:versions) { [Hash("pronto-rubocop" => "42", "rubocop" => "42"), Hash("pronto-haml" => "42", "haml_lint" => "42"), Hash("pronto-yamllint" => "42", "yamllint" => "42")] }

    it "creates a version table" do
      expect(subject).to receive(:versions).and_return(versions).once
      expect(subject.send(:versions_table)).to eq("Pronto Runners | Version | Linters | Version\n--- | --- | --- | ---\npronto-rubocop | 42 | rubocop | 42\npronto-haml | 42 | haml_lint | 42\npronto-yamllint | 42 | yamllint | 42")
    end
  end

  describe "#pronto_format" do
    let(:object) { double("Object") }

    it "calls #looks_good" do
      expect(subject).to receive(:looks_good).once
      subject.send(:pronto_format, [])
    end

    it "calls #process" do
      expect(subject).to receive(:process).with([object]).once
      subject.send(:pronto_format, [object])
    end
  end

  describe "#looks_good" do
    it "returns string" do
      expect(subject.send(:looks_good)).to match(/0 offenses detected :shipit:\nEverything looks fine. :.+:/)
    end
  end

  describe "#process" do
    let(:line) { double("Line", :position => 42) }
    let(:msg_A) { double("Pronto::Message", :path => "file1.rb", :level => :warning, :line => line, :runner => "Pronto::RuboCop", :msg => "Message text.") }
    let(:msg_B) { double("Pronto::Message", :path => "file2.rb", :level => :warning, :line => line, :runner => "Pronto::RuboCop", :msg => "Message text.") }
    let(:messages) { [msg_A, msg_B] }

    it "transforms array of Pronto::Message objects into markdown" do
      expect(subject).to receive(:url_file).and_return("url/to/file").twice
      expect(subject).to receive(:url_file_line).and_return("url/to/file#L42").twice
      expect(subject.send(:process, messages)).to eq("2 offenses detected in 2 files.\n\n---\n\n**[file1.rb](url/to/file)**\n- [ ] :warning: - [Line 42](url/to/file#L42) - RuboCop - Message text.\n\n**[file2.rb](url/to/file)**\n- [ ] :warning: - [Line 42](url/to/file#L42) - RuboCop - Message text.")
    end
  end

  describe "#url_file" do
    let(:branch) { double("Branch", :commit_uri => "https://github.com/owner/repo/and/so/on") }
    let(:msg) { double("Pronto::Message", :path => "path/to/file.txt") }

    it "creates file url" do
      expect(subject).to receive(:commits).and_return(%w(1111 2222 3333)).once
      expect(subject).to receive(:fq_repo_name).and_return("owner/repo").once
      expect(subject).to receive(:branch).and_return(branch).once
      expect(subject.send(:url_file, msg)).to eq("https://github.com/owner/repo/blob/3333/path/to/file.txt")
    end
  end

  describe "#url_file_line" do
    let(:line) { double("Line", :position => 42) }
    let(:msg) { double("Pronto::Message", :path => "path/to/file.txt", :line => line) }
    let(:url) { "https://github.com/owner/repo/blob/3333/path/to/file.txt" }

    it "creates file url with line reference" do
      expect(subject).to receive(:url_file).with(msg).and_return(url).once
      expect(subject.send(:url_file_line, msg)).to eq(url + "#L42")
    end
  end

  describe "#severity_to_emoji" do
    it "return info string" do
      expect(subject.send(:severity_to_emoji, :info)).to eq(":information_source:")
    end

    it "return warning string" do
      expect(subject.send(:severity_to_emoji, :warning)).to eq(":warning:")
    end

    it "return fatal string" do
      expect(subject.send(:severity_to_emoji, :fatal)).to eq(":bomb: :boom: :fire: :fire_engine:")
    end

    it "return error string" do
      expect(subject.send(:severity_to_emoji, :error)).to eq(":bomb: :boom: :fire: :fire_engine:")
    end

    it "return unknown string" do
      expect(subject.send(:severity_to_emoji, :other)).to eq(":sos: :no_entry:")
    end
  end
end
