require_relative 'spec_helper'
require_relative '../issue_manager'
require_relative '../githubapi/git_hub_api'

describe IssueManager do

  RSPEC_ORGANIZATION  = "ManageIQ"
  RSPEC_REPO          = "ManageIQ/sandbox"
  before do
    File.delete(YAML_FILE) rescue nil
  end

  after do
    File.delete(YAML_FILE) rescue nil
  end

  describe "#get_notifications" do
    context "against github.com" do
      it "when there are no notifications" do
        VCR.use_cassette 'issue_manager/no_notifications' do
          lambda { IssueManager.new("sandbox").get_notifications }.should_not raise_error
        end
      end

      it "when there are notifications" do
        VCR.use_cassette 'issue_manager/with_notifications' do
          lambda { IssueManager.new("sandbox").get_notifications }.should_not raise_error
        end
      end
    end

    context "comment processing" do
      before do
        @client             = double("client")
        Octokit::Client.stub(:new => @client)

        octokit_org         = double("octokit_org",
          :login => RSPEC_ORGANIZATION
        )
         
        octokit_org_members = [{"login" => "bronaghs"}, {"login" => "cfme-bot"}]

        octokit_repo        = double("octokit_repo")

        octokit_milestone   = double("octokit_milestone",
          :title => "5.4",
          :number => 1
        )

        octokit_label1      = double("octokit_label",
          :name => "question"
        )
        octokit_label2      = double("octokit_label",
          :name => "wontfix"
        )

        octokit_notification = double("octokit_notification",
         :url        => "https://github.com/ManageIQ/sandbox/issues/123", 
         :subject    => double("subject", :url => "https://github.com/ManageIQ/sandbox/issues/123")
        )

        octokit_repo_milestones = [octokit_milestone]
        octokit_repo_labels     = [octokit_label1, octokit_label2]
        octokit_notifications   = [octokit_notification]

        @octokit_user   = double("octokit_user",
          :login => "cfme-bot"
        )

        @octokit_issue  = double("octokit_issue",
          :number     => "123",
          :title      => "Some title",
          :created_at => Time.now,
          :user       => @octokit_user,
          :body       => "any body"
        )

        GitHubApi.stub(:execute).with(@client, :organization, RSPEC_ORGANIZATION).and_return(octokit_org)
        GitHubApi.stub(:execute).with(@client, :organization_members, RSPEC_ORGANIZATION).and_return(octokit_org_members)
        GitHubApi.stub(:execute).with(@client, :repo, RSPEC_REPO).and_return(octokit_repo)
        GitHubApi.stub(:execute).with(@client, :list_milestones, RSPEC_REPO).and_return(octokit_repo_milestones)
        GitHubApi.stub(:execute).with(@client, :labels, RSPEC_REPO).and_return(octokit_repo_labels)
        GitHubApi.stub(:execute).with(@client, :repository_notifications, RSPEC_REPO, "all" => false).and_return(octokit_notifications)
        GitHubApi.stub(:execute).with(@client, :issue, RSPEC_REPO, @octokit_issue.number).and_return(@octokit_issue)
        GitHubApi.stub(:execute).with(@client, :labels_for_issue, RSPEC_REPO, @octokit_issue.number).and_return(octokit_repo_labels)
        GitHubApi.stub(:execute).with(@client, :mark_thread_as_read, @octokit_issue.number, {"read" => false})

        @octokit_comment = double("octokit_comment",
          :updated_at => Time.now,
          :user => @octokit_user
        )

        @octokit_comments = [@octokit_comment]
      end

      it "assigns to a user" do
        @octokit_comment.stub(:body => "@cfme-bot assign bronaghs")
        GitHubApi.stub(:execute).with(@client, :user, "bronaghs").and_return(true)
        GitHubApi.stub(:execute).with(@client, :issue_comments, RSPEC_REPO, @octokit_issue.number).and_return(@octokit_comments)
        
        GitHubApi.should_receive(:execute).with(@client, :update_issue, RSPEC_REPO,  @octokit_issue.number, @octokit_issue.title, @octokit_issue.body, {"assignee"=>"bronaghs"})
        GitHubApi::Issue.any_instance.should_not_receive(:add_comment)

        im = IssueManager.new("sandbox")
        im.get_notifications
      end

      it "does not assign to an invalid user" do
        @octokit_comment.stub(:body => "@cfme-bot assign Idontexist")
        GitHubApi.stub(:execute).with(@client, :user, "Idontexist").and_raise(Octokit::NotFound)
        GitHubApi.stub(:execute).with(@client, :issue_comments, RSPEC_REPO, @octokit_issue.number).and_return(@octokit_comments)
        
        GitHubApi.should_not_receive(:execute).with(@client, :update_issue, RSPEC_REPO,  @octokit_issue.number, @octokit_issue.title, @octokit_issue.body, {"assignee"=>"Idontexist"})
        GitHubApi::Issue.any_instance.should_receive(:add_comment).with(/invalid user/)

        im = IssueManager.new("sandbox")
        im.get_notifications
      end

      it "adds valid labels" do
        @octokit_comment.stub(:body => "@cfme-bot add_label question, wontfix")
        GitHubApi.stub(:execute).with(@client, :issue_comments, RSPEC_REPO, @octokit_issue.number).and_return(@octokit_comments)

        GitHubApi.should_receive(:execute).with(@client, :add_labels_to_an_issue, RSPEC_REPO,  @octokit_issue.number, ["question", "wontfix"])
        GitHubApi::Issue.any_instance.should_not_receive(:add_comment)

        im = IssueManager.new("sandbox")
        im.get_notifications
      end

      it "add invalid labels" do
        @octokit_comment.stub(:body => "@cfme-bot add_label invalidlabel")
        GitHubApi.stub(:execute).with(@client, :issue_comments, RSPEC_REPO, @octokit_issue.number).and_return(@octokit_comments)

        GitHubApi.should_not_receive(:execute).with(@client, :add_labels_to_an_issue, RSPEC_REPO,  @octokit_issue.number, "invalidlabel")
        GitHubApi::Issue.any_instance.should_receive(:add_comment).with(/Cannot apply/)

        im = IssueManager.new("sandbox")
        im.get_notifications
      end

      it "remove applied label" do
        @octokit_comment.stub(:body => "@cfme-bot remove_label question")
        GitHubApi.stub(:execute).with(@client, :issue_comments, RSPEC_REPO, @octokit_issue.number).and_return(@octokit_comments)

        GitHubApi.should_receive(:execute).with(@client, :remove_label, RSPEC_REPO,  @octokit_issue.number, "question")
        GitHubApi::Issue.any_instance.should_not_receive(:add_comment)

        im = IssueManager.new("sandbox")
        im.get_notifications
      end

      it "remove unapplied label" do
        @octokit_comment.stub(:body => "@cfme-bot remove_label invalidlabel")
        GitHubApi.stub(:execute).with(@client, :issue_comments, RSPEC_REPO, @octokit_issue.number).and_return(@octokit_comments)

        GitHubApi.should_not_receive(:execute).with(@client, :remove_label, RSPEC_REPO,  @octokit_issue.number, "invalidlabel")
        GitHubApi::Issue.any_instance.should_receive(:add_comment).with(/Cannot remove/)

        im = IssueManager.new("sandbox")
        im.get_notifications
      end

      it "extra space in command" do
        @octokit_comment.stub(:body => "@cfme-bot add label question, wontfix")
        GitHubApi.stub(:execute).with(@client, :issue_comments, RSPEC_REPO, @octokit_issue.number).and_return(@octokit_comments)

        GitHubApi.should_not_receive(:execute).with(@client, :add_labels_to_an_issue, RSPEC_REPO,  @octokit_issue.number, "question, wontfix")
        GitHubApi::Issue.any_instance.should_receive(:add_comment).with(/unrecognized command/)

        im = IssueManager.new("sandbox")
        im.get_notifications
      end

      it "extra comma in command values" do
        @octokit_comment.stub(:body => "@cfme-bot add_label question, wontfix,")
        GitHubApi.stub(:execute).with(@client, :issue_comments, RSPEC_REPO, @octokit_issue.number).and_return(@octokit_comments)

        GitHubApi.should_receive(:execute).with(@client, :add_labels_to_an_issue, RSPEC_REPO,  @octokit_issue.number, ["question", "wontfix"])
        GitHubApi::Issue.any_instance.should_not_receive(:add_comment)

        im = IssueManager.new("sandbox")
        im.get_notifications
      end
    end
  end
end
