require 'spec_helper'

RSpec.describe GithubNotificationMonitor do
  subject(:notification_monitor) { described_class.new(repo, username, fq_repo_name) }

  let(:repo)         { double('repo', :notifications => [notification]) }
  let(:notification) { double('notification', :issue_number => issue.number) }
  let(:issue) do
    double('issue',
           :author        => "notchrisarcand",
           :body          => "Opened this issue",
           :number        => 1,
           :created_at    => 10.minutes.ago,
           :list_comments => comments)
  end
  let(:comments) do
    [
      double('comment',
             :author     => "notchrisarcand",
             :updated_at => 5.minutes.ago,
             :body       => comment_body)
    ]
  end
  let(:username)     { "miq-bot" }
  let(:fq_repo_name) { "foo/bar" }

  describe "#process_notifications" do
    before do
      allow(File).to receive(:write)
        .with(described_class::GITHUB_NOTIFICATION_MONITOR_YAML_FILE, anything)
      allow(YAML).to receive(:load_file)
        .with(described_class::GITHUB_NOTIFICATION_MONITOR_YAML_FILE) do
        { "timestamps" => { repo => { issue.number => 10.minutes.ago } } }
      end
      allow(Octokit).to receive(:issue)
      allow(OctokitWrappers::Issue).to receive(:new).and_return(issue)
    end

    after do
      described_class.new(repo, username, fq_repo_name).process_notifications
    end

    context "when 'assign' command is given" do
      let(:comment_body) { "@#{username} assign #{assignee}" }

      before do
        allow(repo).to receive(:valid_assignee?).with("gooduser") { true }
        allow(repo).to receive(:valid_assignee?).with("baduser") { false }
      end

      context "with a valid user" do
        let(:assignee) { "gooduser" }

        it "assigns to that user and marks notification as read" do
          expect(issue).to receive(:assign).with(assignee)
          expect(notification).to receive(:mark_thread_as_read)
        end
      end

      context "with an invalid user" do
        let(:assignee) { "baduser" }

        it "does not assign after reloading the cache on first failure, reports failure, and marks as read" do
          expect(repo).to receive(:refresh_assignees)
          expect(issue).not_to receive(:assign)
          expect(issue).to receive(:add_comment).with(/invalid assignee/)
          expect(notification).to receive(:mark_thread_as_read)
        end
      end
    end

    context "when 'add_labels' command is given" do
      before do
        allow(issue).to receive(:applied_label?).and_return(false)
        allow(repo).to receive(:valid_label?).and_return(false)
        %w(question wontfix).each do |label|
          allow(repo).to receive(:valid_label?).with(label).and_return(true)
        end
      end

      context "with valid labels" do
        let(:comment_body) { "@#{username} add-label question, wontfix" }

        it "adds the labels and marks as read" do
          expect(issue).to receive(:add_labels) do |labels|
            expect(labels).to contain_exactly("question", "wontfix")
          end
          expect(notification).to receive(:mark_thread_as_read)
        end

        context "with extra space in command" do
          let(:comment_body) { "@#{username} add label question, wontfix" }

          it "doesn't add labels, comments on error, and marks as read" do
            expect(issue).not_to receive(:add_labels)
            expect(issue).to receive(:add_comment).with(/unrecognized command 'add'/)
            expect(notification).to receive(:mark_thread_as_read)
          end
        end

        context "with extra comma in command values and marks as read" do
          let(:comment_body) { "@#{username} add-label question, wontfix," }

          it "adds the labels" do
            expect(issue).to receive(:add_labels) do |labels|
              expect(labels).to contain_exactly("question", "wontfix")
            end
            expect(notification).to receive(:mark_thread_as_read)
          end
        end
      end

      context "with invalid labels" do
        let(:comment_body) { "@#{username} add-label invalidlabel" }

        it "does not add invalid labels after refreshing cache, comments on error, and marks as read" do
          expect(repo).to receive(:refresh_labels)
          expect(issue).not_to receive(:add_labels)
          expect(issue).to receive(:add_comment).with(/Cannot apply the following label.*not recognized/)
          expect(notification).to receive(:mark_thread_as_read)
        end
      end
    end

    context "when 'remove_labels' command is given" do
      before do
        allow(repo).to receive(:valid_label?).with("question").and_return(true)
      end

      context "with applied labels" do
        let(:comment_body) { "@#{username} remove-label question" }

        it "removes the applied label and marks as read" do
          expect(issue).to receive(:applied_label?).and_return(true)
          expect(issue).to receive(:remove_label).with("question")
          expect(notification).to receive(:mark_thread_as_read)
        end
      end

      context "with unapplied labels" do
        let(:comment_body) { "@#{username} remove-label question" }

        it "doesn't remove any labels and marks as read" do
          expect(issue).to receive(:applied_label?).and_return(false)
          expect(issue).not_to receive(:remove_label)
          expect(notification).to receive(:mark_thread_as_read)
        end
      end
    end
  end
end
