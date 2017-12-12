# rubocop:disable Style/NumericLiterals, Style/IndentArray
require 'spec_helper'

describe BugzillaService do
  let(:service) { double("bugzilla service") }

  before do
    allow_any_instance_of(described_class).to receive(:service).and_return(service)
  end

  def with_service
    described_class.call { |bz| yield bz }
  end

  def commit_message(body)
    <<-EOF
commit 0123456789abcdef0123456789abcdef01234567
Author:     Some Author <some.author@example.com>
AuthorDate: Mon Nov 13 13:57:41 2017 -0500
Commit:     Some Committer <some.committer@example.com>
CommitDate: Mon Nov 13 14:16:33 2017 -0500

    #{body.chomp.gsub("\n", "\n    ")}

 lib/miq_bot.rb | 5 +++++
 1 file changed, 5 insertions(+)
    EOF
  end

  it_should_behave_like "ThreadsafeServiceMixin service"

  describe ".search_in_message" do
    before do
      stub_settings(:bugzilla_credentials => {:url => "https://bugzilla.redhat.com"})
    end

    it "with no bugs" do
      message = commit_message(<<-EOF)
This is a commit message
      EOF

      expect(described_class.search_in_message(message)).to eq([])
    end

    it "with one bug (with regular format)" do
      message = commit_message(<<-EOF)
This is a commit message

https://bugzilla.redhat.com/123456
      EOF

      expect(described_class.search_in_message(message)).to eq([
        {:resolution => nil, :bug_id => 123456}
      ])
    end

    it "with one bug (with cgi format)" do
      message = commit_message(<<-EOF)
This is a commit message

https://bugzilla.redhat.com/show_bug.cgi?id=123456
      EOF

      expect(described_class.search_in_message(message)).to eq([
        {:resolution => nil, :bug_id => 123456}
      ])
    end

    it "with multiple bugs" do
      message = commit_message(<<-EOF)
This is a commit message

https://bugzilla.redhat.com/show_bug.cgi?id=123456
https://bugzilla.redhat.com/345678
      EOF

      expect(described_class.search_in_message(message)).to eq([
        {:resolution => nil, :bug_id => 123456},
        {:resolution => nil, :bug_id => 345678}
      ])
    end

    it "when the URL in settings has a trailing slash" do
      stub_settings(:bugzilla_credentials => {:url => "https://bugzilla.redhat.com/"})

      message = commit_message(<<-EOF)
This is a commit message

https://bugzilla.redhat.com/show_bug.cgi?id=123456
https://bugzilla.redhat.com/345678
      EOF

      expect(described_class.search_in_message(message)).to eq([
        {:resolution => nil, :bug_id => 123456},
        {:resolution => nil, :bug_id => 345678}
      ])
    end

    it "when the URL in settings not set" do
      stub_nil_settings(:bugzilla_credentials => {:url => nil})

      message = commit_message(<<-EOF)
This is a commit message

https://bugzilla.redhat.com/show_bug.cgi?id=123456
https://bugzilla.redhat.com/345678
      EOF

      expect(described_class.search_in_message(message)).to eq([])
    end

    it "with oddly formed URL" do
      message = commit_message(<<-EOF)
This is a commit message

https://bugzilla.redhat.com//show_bug.cgi?id=123456
      EOF

      expect(described_class.search_in_message(message)).to eq([
        {:resolution => nil, :bug_id => 123456}
      ])
    end

    described_class::CLOSING_KEYWORDS.each do |base_word|
      [base_word, base_word.capitalize, "#{base_word}:", "#{base_word.capitalize}:"].each do |keyword|
        it "detects an id when the URL is prefixed with closing keyword '#{keyword}'" do
          message = commit_message(<<-EOF)
This is a commit message

#{keyword} https://bugzilla.redhat.com/show_bug.cgi?id=123456
#{keyword} https://bugzilla.redhat.com/345678
  EOF

          expect(described_class.search_in_message(message)).to eq([
            {:resolution => base_word, :bug_id => 123456},
            {:resolution => base_word, :bug_id => 345678}
          ])
        end
      end
    end
  end

  describe ".ids_in_git_commit_message" do
    before do
      stub_settings(:bugzilla_credentials => {:url => "https://bugzilla.redhat.com"})
    end

    it "with no bugs" do
      message = commit_message(<<-EOF)
This is a commit message
      EOF

      expect(described_class.ids_in_git_commit_message(message)).to eq([])
    end

    it "with one bug (with regular format)" do
      message = commit_message(<<-EOF)
This is a commit message

https://bugzilla.redhat.com/123456
      EOF

      expect(described_class.ids_in_git_commit_message(message)).to eq([123456])
    end

    it "with one bug (with cgi format)" do
      message = commit_message(<<-EOF)
This is a commit message

https://bugzilla.redhat.com/show_bug.cgi?id=123456
      EOF

      expect(described_class.ids_in_git_commit_message(message)).to eq([123456])
    end

    it "with multiple bugs" do
      message = commit_message(<<-EOF)
This is a commit message

https://bugzilla.redhat.com/show_bug.cgi?id=123456
https://bugzilla.redhat.com/345678
      EOF

      expect(described_class.ids_in_git_commit_message(message)).to eq([123456, 345678])
    end

    it "when the URL in settings has a trailing slash" do
      stub_settings(:bugzilla_credentials => {:url => "https://bugzilla.redhat.com/"})

      message = commit_message(<<-EOF)
This is a commit message

https://bugzilla.redhat.com/show_bug.cgi?id=123456
https://bugzilla.redhat.com/345678
      EOF

      expect(described_class.ids_in_git_commit_message(message)).to eq([123456, 345678])
    end

    it "when the URL in settings not set" do
      stub_nil_settings(:bugzilla_credentials => {:url => nil})

      message = commit_message(<<-EOF)
This is a commit message

https://bugzilla.redhat.com/show_bug.cgi?id=123456
https://bugzilla.redhat.com/345678
      EOF

      expect(described_class.ids_in_git_commit_message(message)).to eq([])
    end

    it "with oddly formed URL" do
      message = commit_message(<<-EOF)
This is a commit message

https://bugzilla.redhat.com//show_bug.cgi?id=123456
      EOF

      expect(described_class.ids_in_git_commit_message(message)).to eq([123456])
    end

    described_class::CLOSING_KEYWORDS.each do |base_word|
      [base_word, base_word.capitalize, "#{base_word}:", "#{base_word.capitalize}:"].each do |keyword|
        it "detects an id when the URL is prefixed with closing keyword '#{keyword}'" do
          message = commit_message(<<-EOF)
This is a commit message

#{keyword} https://bugzilla.redhat.com/show_bug.cgi?id=123456
#{keyword} https://bugzilla.redhat.com/345678
EOF

          expect(described_class.ids_in_git_commit_message(message)).to eq([123456, 345678])
        end
      end
    end
  end

  describe "#find_bug" do
    let(:bug) { double(ActiveBugzilla::Bug) }

    it "without a product in settings" do
      expect(ActiveBugzilla::Bug).to receive(:find).with(:product => nil, :id => 123456).and_return([bug])

      with_service { |bz| expect(bz.find_bug(123456)).to eq(bug) }
    end

    it "with a product in settings" do
      stub_settings(:bugzilla => {:product => "ManageIQ"})
      expect(ActiveBugzilla::Bug).to receive(:find).with(:product => "ManageIQ", :id => 123456).and_return([bug])

      with_service { |bz| expect(bz.find_bug(123456)).to eq(bug) }
    end
  end

  context "native bz methods" do
    it "#search" do
      expect(service).to receive(:search).with(:id => 123456)
      with_service { |bz| bz.search(:id => 123456) }
    end

    it "#add_comment" do
      expect(service).to receive(:add_comment).with(123456, "Fixed")
      with_service { |bz| bz.add_comment(123456, "Fixed") }
    end
  end
end
