RSpec.describe GithubService::CommandDispatcher do
  describe ".find_command_class" do
    it "with direct names" do
      expect(described_class.find_command_class("assign")).to eq(GithubService::Commands::Assign)
    end

    it "with underscore name" do
      expect(described_class.find_command_class("add_label")).to eq(GithubService::Commands::AddLabel)
    end

    it "with hyphenated name" do
      expect(described_class.find_command_class("add-label")).to eq(GithubService::Commands::AddLabel)
    end

    it "with plural underscore name" do
      expect(described_class.find_command_class("add_labels")).to eq(GithubService::Commands::AddLabel)
    end

    it "with plural hyphenated name" do
      expect(described_class.find_command_class("add-labels")).to eq(GithubService::Commands::AddLabel)
    end

    it "with underscore alias" do
      expect(described_class.find_command_class("rm_label")).to eq(GithubService::Commands::RemoveLabel)
    end

    it "with hyphenated alias" do
      expect(described_class.find_command_class("rm-label")).to eq(GithubService::Commands::RemoveLabel)
    end

    it "with plural underscore alias" do
      expect(described_class.find_command_class("rm_labels")).to eq(GithubService::Commands::RemoveLabel)
    end

    it "with plural hyphenated alias" do
      expect(described_class.find_command_class("rm-labels")).to eq(GithubService::Commands::RemoveLabel)
    end

    it "with an unknown command" do
      expect(described_class.find_command_class("does-not-exist")).to be_nil
    end
  end

  describe ".available_commands" do
    it "returns a list of all commands" do
      expect(described_class.available_commands).to include("add_label")
      expect(described_class.available_commands).to include("remove_label")
    end

    it "does not include aliases" do
      expect(described_class.available_commands).to_not include("rm_label")
    end
  end

  describe "#dispatch!" do
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

      context "if the bot is the target" do
        let(:command_issuer) { bot_name }

        it "does nothing" do
          expect(GithubService::Commands::Assign).to receive(:new).never
          expect(command_class).to receive(:execute!).never
        end
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
  end
end
