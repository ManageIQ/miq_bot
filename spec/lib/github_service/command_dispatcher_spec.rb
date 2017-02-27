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
      command_dispatcher.dispatch!(author: command_issuer, text: text)
    end

    context "when 'assign' command is given" do
      let(:text) { "@#{bot_name} assign #{assignee}" }

      before do
        allow(GithubService).to receive(:valid_assignee?).with(fq_repo_name, "gooduser") { true }
        allow(GithubService).to receive(:valid_assignee?).with(fq_repo_name, "baduser") { false }
      end

      context "with a valid user" do
        let(:assignee) { "gooduser" }

        it "assigns to that user" do
          expect(command_dispatcher.issue).to receive(:assign).with(assignee)
        end
      end

      context "with an invalid user" do
        let(:assignee) { "baduser" }

        it "does not assign, reports failure" do
          expect(command_dispatcher.issue).not_to receive(:assign)
          expect(command_dispatcher.issue).to receive(:add_comment).with("@#{command_issuer} #{assignee} is an invalid assignee, ignoring...")
        end
      end
    end

    context "when 'add_labels' command is given" do
      before do
        allow(command_dispatcher.issue).to receive(:applied_label?).and_return(false)
        allow(GithubService).to receive(:valid_label?).and_return(false)
        %w(question wontfix).each do |label|
          allow(GithubService).to receive(:valid_label?).with(fq_repo_name, label).and_return(true)
        end
      end

      context "with valid labels" do
        let(:text) { "@#{bot_name} add-label question, wontfix" }

        it "adds the labels and marks as read" do
          expect(command_dispatcher.issue).to receive(:add_labels) do |labels|
            expect(labels).to contain_exactly("question", "wontfix")
          end
        end

        context "with extra space in command" do
          let(:text) { "@#{bot_name} add label question, wontfix" }

          it "doesn't add labels, comments on error, and marks as read" do
            expect(command_dispatcher.issue).not_to receive(:add_labels)
            expect(command_dispatcher.issue).to receive(:add_comment)
              .with(a_string_including("@#{command_issuer} unrecognized command 'add'"))
          end
        end

        context "with extra comma in command values and marks as read" do
          let(:text) { "@#{bot_name} add-label question, wontfix," }

          it "adds the labels" do
            expect(command_dispatcher.issue).to receive(:add_labels) do |labels|
              expect(labels).to contain_exactly("question", "wontfix")
            end
          end
        end
      end

      context "with invalid labels" do
        let(:text) { "@#{bot_name} add-label invalidlabel" }

        it "does not add invalid labels, comments on error, and marks as read" do
          expect(command_dispatcher.issue).not_to receive(:add_labels)
          expect(command_dispatcher.issue).to receive(:add_comment).with(/Cannot apply the following label.*not recognized/)
        end
      end
    end

    context "when 'remove_labels' command is given" do
      before do
        allow(GithubService).to receive(:valid_label?).with(fq_repo_name, "question").and_return(true)
      end

      context "with applied labels" do
        let(:text) { "@#{bot_name} remove-label question" }

        it "removes the applied label and marks as read" do
          expect(command_dispatcher.issue).to receive(:applied_label?).and_return(true)
          expect(command_dispatcher.issue).to receive(:remove_label).with("question")
        end
      end

      context "with unapplied labels" do
        let(:text) { "@#{bot_name} remove-label question" }

        it "doesn't remove any labels and marks as read" do
          expect(command_dispatcher.issue).to receive(:applied_label?).and_return(false)
          expect(command_dispatcher.issue).not_to receive(:remove_label)
        end
      end
    end
  end
end
