require 'spec_helper'

RSpec.describe GithubService::Commands::AddLabel do
  subject { described_class.new(issue) }
  let(:issue) { double(:fq_repo_name => "foo/bar") }
  let(:labels) { %w[question wontfix] }
  let(:command_issuer) { "chessbyte" }
  let(:command_value) { "question, wontfix" }

  let(:miq_teams) do
    [
      {"id" => 1234, "name" => "commiters"},
      {"id" => 2345, "name" => "core-triage"},
      {"id" => 3456, "name" => "my-triage-team"},
      {"id" => 4567, "name" => "UI"}
    ]
  end

  before do
    allow(issue).to receive(:applied_label?).with("question").and_return(true)
    allow(issue).to receive(:applied_label?).with("wontfix").and_return(false)
    allow(GithubService).to receive(:labels).with(issue.fq_repo_name).and_return(labels)
    labels.each do |label|
      allow(GithubService).to receive(:valid_label?).with("foo/bar", label).and_return(true)
    end
    allow(GithubService).to receive(:valid_label?).with("foo/bar", "wont fix").and_return(false)
  end

  after do
    # unset class variables (weird ordering thanks to @chrisarcand...)
    [:@triage_team_name, :@member_organization_name].each do |var|
      IsTeamMember.remove_instance_variable(var) if IsTeamMember.instance_variable_defined?(var)
    end

    subject.execute!(:issuer => command_issuer, :value => command_value)
  end

  context "with valid labels" do
    it "adds the unapplied labels" do
      expect(issue).to receive(:add_labels).with(["wontfix"])
    end
  end

  context "with slightly misspelled labels" do
    let(:command_value) { "question, wont fix" }

    it "corrects and adds the unapplied labels (if there is only one option)" do
      expect(issue).to receive(:add_labels).with(["wontfix"])
    end

    context "with multiple options for misspellings" do
      let(:labels) { %w[question wontfix wont-fix] }

      it "does not add invalid labels" do
        expect(issue).to receive(:add_comment)
        expect(issue).not_to receive(:add_labels)
      end

      it "comments on error and provides corrections as options" do
        err_comment = <<~ERR.chomp
          @#{command_issuer} Cannot apply the following label because they are not recognized:
          * `wont fix` (Did you mean? `wontfix`, `wont-fix`)

          All labels for `foo/bar`:  https://github.com/foo/bar/labels
        ERR
        expect(issue).to receive(:add_comment).with(err_comment)
      end
    end
  end

  context "with invalid labels" do
    let(:command_value) { "invalidlabel" }

    before do
      allow(GithubService).to receive(:valid_label?).with("foo/bar", command_value).and_return(false)
    end

    it "does not add invalid labels and comments on error" do
      expect(issue).not_to receive(:add_labels)
      expect(issue).to receive(:add_comment).with(/Cannot apply the following label.*not recognized/)
    end
  end

  context "un-assignable labels" do
    let(:command_value)  { "jansa/yes" }
    let(:triage_members) { [{"login" => "Fryguy"}] }

    before do
      github_service_add_stub :url           => "/orgs/ManageIQ/teams?per_page=100",
                              :response_body => miq_teams.to_json
      github_service_add_stub :url           => "/teams/3456/members?per_page=100",
                              :response_body => triage_members.to_json
    end

    context "without a triage team" do
      before do
        allow(issue).to receive(:applied_label?).with("jansa/yes?").and_return(false)
        allow(GithubService).to receive(:valid_label?).with("foo/bar", command_value).and_return(true)
      end

      it "corrects the label to 'jansa/yes?'" do
        expect(issue).to receive(:add_labels).with(["jansa/yes?"])
        expect(issue).not_to receive(:add_comment)
      end
    end

    context "with a non-triage user" do
      before do
        allow(issue).to receive(:applied_label?).with("jansa/yes?").and_return(false)
        allow(GithubService).to receive(:valid_label?).with("foo/bar", command_value).and_return(true)
        stub_settings(:member_organization_name => "ManageIQ", :triage_team_name => "my-triage-team")
      end

      it "applies the original label" do
        expect(issue).to receive(:add_labels).with(["jansa/yes?"])
        expect(issue).not_to receive(:add_comment)
      end
    end

    context "with a triage user" do
      let(:triage_members) do
        [
          {"login" => "Fryguy"},
          {"login" => command_issuer}
        ]
      end

      before do
        allow(issue).to receive(:applied_label?).with("jansa/yes").and_return(false)
        allow(GithubService).to receive(:valid_label?).with("foo/bar", command_value).and_return(true)
        stub_settings(:member_organization_name => "ManageIQ", :triage_team_name => "my-triage-team")
      end

      it "applies the original label" do
        expect(issue).to receive(:add_labels).with(["jansa/yes"])
        expect(issue).not_to receive(:add_comment)
      end
    end
  end
end
