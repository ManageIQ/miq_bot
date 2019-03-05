# rubocop:disable Style/NumericLiterals, Layout/IndentArray
require 'spec_helper'

describe BugzillaService do
  # Clear service settings
  after do
    BugzillaService.instance_variable_set(:@product, nil)
    BugzillaService.instance_variable_set(:@credentials, nil)
  end

  def with_service
    described_class.call { |bz| yield bz }
  end

  def stub_credentials(credentials)
    stub_settings(credentials)
    BugzillaService.credentials = Settings.bugzilla_credentials
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
    let(:bugzilla_auth) { { :username => "user", :password => "pass" } }

    it "without a product in settings will raise an error" do
      expect { BugzillaService.product = nil }.to raise_error(RuntimeError)
    end

    it "with a product in settings makes the request" do
      BugzillaService.product = "ManageIQ"
      stub_credentials(:bugzilla_credentials => bugzilla_auth)

      bugzilla_stubs = Faraday.new do |builder|
        builder.adapter :test do |stub|
          uri = "/rest/bug?id=123456&product=ManageIQ&include_fields=id,status"
          stub.get(uri) do
            [200, {}, '{"bugs": [{"id": 123456, "status": "POST"}]}']
          end
        end
      end

      BugzillaService.call do |bz|
        expect(bz).to receive(:connection).and_return(bugzilla_stubs)

        bug = bz.find_bug(123456)

        expect(bug).to        be_kind_of(BugzillaService::Bug)
        expect(bug.id).to     eq(123456)
        expect(bug.status).to eq("POST")
      end
    end
  end

  describe BugzillaService::Bug do
    before do
      bugzilla_auth = { :username => "user", :password => "pass" }
      stub_credentials(:bugzilla_credentials => bugzilla_auth)
    end

    describe "#comments" do
      let(:comment_data) do
        {
          "bugs" => {
            "123456" => {
              "comments" => [
                {"text" => "Comment 1"},
                {"text" => "Comment 2"},
                {"text" => "Comment 4... wait... what happened to 3!?"}
              ]
            }
          }
        }
      end

      def bugzilla_stubs(response_code = 200)
        Faraday.new do |builder|
          builder.adapter :test do |stub|
            stub.get("/rest/bug/123456/comment") do
              if response_code == 200
                [200, {}, comment_data.to_json]
              else
                [404, {}, '']
              end
            end
          end
        end
      end

      it "returns an empty array if the request was not 200" do
        BugzillaService.call do |bz|
          expect(bz).to receive(:connection).and_return(bugzilla_stubs(404))
          bug = BugzillaService::Bug.new(bz, 123456, "DOES_NOT_MATTER")
          expect(bug.comments).to eq([])
        end
      end

      it "returns just the text of the comments for a Bug" do
        BugzillaService.call do |bz|
          expect(bz).to receive(:connection).and_return(bugzilla_stubs)

          bug      = BugzillaService::Bug.new(bz, 123456, "DOES_NOT_MATTER")
          comments = bug.comments

          expect(comments.size).to   eq(3)
          expect(comments.first).to  eq("Comment 1")
          expect(comments.last).to   eq("Comment 4... wait... what happened to 3!?")
        end
      end
    end

    describe "#add_comment" do
      def bugzilla_stubs(response_code = 200)
        Faraday.new do |builder|
          builder.adapter :test do |stub|
            payload = { "comment" => "It matters!"}.to_json
            headers = { "Content-Type" => "application/json" }
            stub.post("/rest/bug/123456/comment", payload, headers) do
              [response_code, {}, '']
            end
          end
        end
      end

      it "returns true when the comment is created successfully" do
        BugzillaService.call do |bz|
          expect(bz).to receive(:connection).and_return(bugzilla_stubs)

          bug = BugzillaService::Bug.new(bz, 123456, "DOES_NOT_MATTER")
          expect(bug.add_comment("It matters!")).to eq(true)
        end
      end

      it "returns false when the adding comment fails" do
        BugzillaService.call do |bz|
          expect(bz).to receive(:connection).and_return(bugzilla_stubs(500))

          bug = BugzillaService::Bug.new(bz, 123456, "DOES_NOT_MATTER")
          expect(bug.add_comment("It matters!")).to eq(false)
        end
      end
    end

    describe "#save" do
      def bugzilla_stubs(response_code = 200)
        Faraday.new do |builder|
          builder.adapter :test do |stub|
            payload = { "ids" => [123456], "status" => "POST" }.to_json
            headers = { "Content-Type" => "application/json" }
            stub.put("/rest/bug/123456", payload, headers) do
              [response_code, {}, '']
            end
          end
        end
      end

      it "returns true when the update succeeds" do
        BugzillaService.call do |bz|
          expect(bz).to receive(:connection).and_return(bugzilla_stubs)

          bug = BugzillaService::Bug.new(bz, 123456, "ON_DEV")
          bug.status = "POST"
          expect(bug.save).to eq(true)
        end
      end

      it "returns false when the update fails" do
        BugzillaService.call do |bz|
          expect(bz).to receive(:connection).and_return(bugzilla_stubs(500))

          bug        = BugzillaService::Bug.new(bz, 123456, "ON_DEV")
          bug.status = "POST"
          expect(bug.save).to eq(false)
        end
      end
    end
  end
end
# rubocop:enable Style/NumericLiterals, Layout/IndentArray
