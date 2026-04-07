RSpec.describe GithubService::Commands::RemoveLabel do
  subject { described_class.new(issue) }
  let(:issue) { double(:fq_repo_name => "foo/bar") }
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

  after do
    # unset class variables (weird ordering thanks to @chrisarcand...)
    [:@triage_team_name, :@member_organization_name].each do |var|
      IsTeamMember.remove_instance_variable(var) if IsTeamMember.instance_variable_defined?(var)
    end

    subject.execute!(:issuer => command_issuer, :value => command_value)
  end

  context "with valid labels" do
    before do
      %w[question wontfix].each do |label|
        allow(GithubService).to receive(:valid_label?).with("foo/bar", label).and_return(true)
      end
    end

    context "when the labels are applied" do
      before do
        %w[question wontfix].each do |label|
          expect(issue).to receive(:applied_label?)
            .with(label).and_return(true)
        end
      end

      it "removes the labels" do
        %w[question wontfix].each do |label|
          expect(issue).to receive(:remove_label).with(label)
        end
      end
    end

    context "with some unapplied labels" do
      before do
        expect(issue).to receive(:applied_label?).with("question").and_return(true)
        expect(issue).to receive(:applied_label?).with("wontfix").and_return(false)
      end

      it "only removes the applied label" do
        expect(issue).to receive(:remove_label).with("question")
        expect(issue).not_to receive(:remove_label).with("wontfix")
      end
    end

    context "with labels that are UNREMOVABLE" do
      # An invalid situation, just testing in one go
      let(:command_value)  { "wontfix, jansa/no, jansa/yes, jansa/yes?" }
      let(:triage_members) { [{"login" => "Fryguy"}] }

      before do
        github_service_add_stub :url           => "/orgs/ManageIQ/teams?per_page=100",
                                :response_body => miq_teams.to_json
        github_service_add_stub :url           => "/teams/3456/members?per_page=100",
                                :response_body => triage_members.to_json

        # Assume all labels are valid
        allow(GithubService).to receive(:valid_label?).and_return(true)
        # Assume all labels are currently applied
        allow(issue).to receive(:applied_label?).and_return(true)
      end

      context "without a triage team" do
        before do
          message = "@chessbyte Cannot remove the following labels since they require " \
                    "[triage team permissions](https://github.com/orgs/ManageIQ/teams/core-triage)" \
                    ": jansa/no, jansa/yes"

          expect(issue).to receive(:add_comment).with(message)
        end

        it "only removes the removable applied labels" do
          expect(issue).to     receive(:remove_label).with("wontfix")
          expect(issue).not_to receive(:remove_label).with("jansa/no")
          expect(issue).not_to receive(:remove_label).with("jansa/yes")
          expect(issue).to     receive(:remove_label).with("jansa/yes?")
        end
      end

      context "with a triage team" do
        before do
          message = "@chessbyte Cannot remove the following labels since they require " \
                    "[triage team permissions](https://github.com/orgs/ManageIQ/teams/core-triage)" \
                    ": jansa/no, jansa/yes"

          expect(issue).to receive(:add_comment).with(message)
          stub_settings(:member_organization_name => "ManageIQ", :triage_team_name => "my-triage-team")
        end

        it "only removes the removable applied labels" do
          expect(issue).to     receive(:remove_label).with("wontfix")
          expect(issue).not_to receive(:remove_label).with("jansa/no")
          expect(issue).not_to receive(:remove_label).with("jansa/yes")
          expect(issue).to     receive(:remove_label).with("jansa/yes?")
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
          stub_settings(:member_organization_name => "ManageIQ", :triage_team_name => "my-triage-team")
        end

        it "only removes the applied label" do
          expect(issue).to receive(:remove_label).with("wontfix")
          expect(issue).to receive(:remove_label).with("jansa/no")
          expect(issue).to receive(:remove_label).with("jansa/yes")
          expect(issue).to receive(:remove_label).with("jansa/yes?")
        end
      end

      context "with string and regex patterns in unremovable labels" do
        let(:command_value) { "wontfix, jansa/no, test/foo" }

        before do
          message = "@chessbyte Cannot remove the following labels since they require " \
                    "[triage team permissions](https://github.com/orgs/ManageIQ/teams/core-triage)" \
                    ": jansa/no, test/foo"

          expect(issue).to receive(:add_comment).with(message)
        end

        it "treats exact strings and regexps as unremovable" do
          expect(issue).to     receive(:remove_label).with("wontfix")
          expect(issue).not_to receive(:remove_label).with("jansa/no")
          expect(issue).not_to receive(:remove_label).with("test/foo")
        end
      end
    end
  end
end
