require 'spec_helper'

RSpec.describe GithubService::CommandDispatcher do
  subject(:command_dispatcher) { described_class.new(issue) }

  let(:bot_name)       { "miq-bot" }
  let(:command_issuer) { "chessbyte" }
  let(:fq_repo_name)   { "foo/bar" }
  let(:issue) do
    double('issue',
           :user           => double(:login => "chrisarcand"),
           :body           => "Opened this issue",
           :number         => 1,
           :labels         => [],
           :repository_url => "https://api.fakegithub.com/repos/#{fq_repo_name}")
  end

  describe "#dispatch!" do
    before do
      allow(Settings).to receive(:github_credentials).and_return(double(:username => bot_name))
    end

    after do
      command_dispatcher.dispatch!(:issuer => command_issuer, :text => text)
    end

    context "when 'assign' command is given" do
      let(:text) { "@#{bot_name} assign chrisarcand" }
      let(:command_class) { double }

      it "dispatches to Assign" do
        expect(GithubService::Commands::Assign).to receive(:new).and_return(command_class)
        expect(command_class).to receive(:execute!)
          .with(:issuer => command_issuer, :value => "chrisarcand")
      end
    end

    context "when 'add_labels' command is given" do
      let(:text) { "@#{bot_name} add-label question, wontfix" }
      let(:command_class) { double }

      it "dispatches to AddLabel" do
        expect(GithubService::Commands::AddLabel).to receive(:new).and_return(command_class)
        expect(command_class).to receive(:execute!)
          .with(:issuer => command_issuer, :value => "question, wontfix")
      end

      context "with extra space in command" do
        let(:text) { "@#{bot_name} add label question, wontfix" }

        it "doesn't dispatch and comments on error" do
          expect(GithubService::Commands::AddLabel).to_not receive(:new)
          expect(command_dispatcher.issue).to receive(:add_comment)
            .with(a_string_including("@#{command_issuer} unrecognized command 'add'"))
        end
      end
    end

    context "when 'remove_labels' command is given" do
      let(:text) { "@#{bot_name} remove-label question" }
      let(:command_class) { double }

      it "dispatches to RemoveLabel" do
        expect(GithubService::Commands::RemoveLabel).to receive(:new).and_return(command_class)
        expect(command_class).to receive(:execute!)
          .with(:issuer => command_issuer, :value => "question")
      end
    end

    context "when 'run_tests' command is given" do
      let(:text) { "@#{bot_name} run_tests manageiq-ui-classic" }
      let(:command_class) { double }

      it "dispatches to RunTests" do
        expect(GithubService::Commands::RunTests).to receive(:new).and_return(command_class)
        expect(command_class).to receive(:execute!)
          .with(:issuer => command_issuer, :command => "run_tests", :value => "manageiq-ui-classic")
      end
    end

    context "when 'run_tests' command is given" do
      let(:text) { "@#{bot_name} run_tests manageiq-ui-classic,manageiq-api" }
      let(:command_class) { double }

      it "dispatches to RunTests" do
        expect(GithubService::Commands::RunTests).to receive(:new).and_return(command_class)
        expect(command_class).to receive(:execute!)
          .with(:issuer => command_issuer, :command => "run_tests", :value => "manageiq-ui-classic,manageiq-api")
      end
    end
  end
end
