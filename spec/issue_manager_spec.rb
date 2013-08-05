require_relative 'spec_helper'
require_relative '../issue_manager'

describe IssueManager do
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
          lambda { IssueManager.new.get_notifications }.should_not raise_error
        end
      end

      it "when there are notifications" do
        VCR.use_cassette 'issue_manager/with_notifications' do
          lambda { IssueManager.new.get_notifications }.should_not raise_error
        end
      end
    end

    context "with mocked data" do
      before do
        @issue = double("issue",
          :number => "123",
          :title  => "Some title",
          :body   => "Some body"
        )

        r = double("repository", :name => "sandbox")
        n1 = double("notification",
          :repository => r,
          :url        => "https://github.com/ManageIQ/sandbox/issues/#{@issue.number}", 
          :subject    => double("subject", :url => "https://github.com/ManageIQ/sandbox/issues/#{@issue.number}"), 
        )

        u = double("user",
          :login => "jrafanie",
          :company => "redhat"
        )

        @label = double("label",
          :url      => "https://api.github.com/repos/octocat/Hello-World/labels/bug",
          :name     => "bug",
          :color    => "f29513"
        )


        @client = double("client",
          :repository_notifications => [n1],
          :issue                    => @issue,
          :user                     => u
        )
         
        IssueManager.any_instance.stub(:check_user_organization => "true")
        IssueManager.any_instance.stub(:load_organization_members => ["bronaghs", "cfme-bot"])
        IssueManager.any_instance.stub(:load_permitted_labels => ["bug", "question", "wontfix"])
        IssueManager.any_instance.stub(:client => @client)

      end

      it "assigns to a user" do
        ic = double("issue_comment",
          :body       => "@cfme-bot assign @jrafanie",
          :updated_at => Time.now
        )

        @client.stub(:issue_comments => [ic])
        @client.should_receive(:update_issue).with("ManageIQ/sandbox", @issue.number, @issue.title, @issue.body, {"assignee"=>"jrafanie"})
        @client.should_receive(:mark_thread_as_read).with(@issue.number, {"read" => false})
        IssueManager.new.get_notifications
      end

      it "should not assign to an invalid user" do
        ic = double("issue_comment",
          :body       => "@cfme-bot assign @blah",
          :updated_at => Time.now
        )

        @client.stub(:issue_comments => [ic])
        @client.should_not_receive(:update_issue).with("ManageIQ/sandbox", @issue.number, @issue.title, @issue.body, {"assignee"=>"@blah"})
        @client.should_receive(:mark_thread_as_read).with(@issue.number, {"read" => false})
        IssueManager.new.get_notifications
      end

      it "adds labels to an issue" do
        ic = double("issue_comment",
          :body       => "@cfme-bot add_label bug, question",
          :updated_at => Time.now
        )

        @client.stub(:issue_comments => [ic])
        @client.should_receive(:add_labels_to_an_issue).with("ManageIQ/sandbox", @issue.number,  ["bug", "question"])
        @client.should_receive(:mark_thread_as_read).with(@issue.number.to_s, {"read" => false})
        IssueManager.any_instance.stub(:check_permitted_label => true)
        IssueManager.new.get_notifications

      end

      it "invalid labels are not applied to an issue" do
        ic = double("issue_comment",
          :body       => "@cfme-bot add_label invalid, invalidagain",
          :updated_at => Time.now
        )
        @client.stub(:issue_comments => [ic])

        @client.should_not_receive(:add_labels_to_an_issue)
        @client.should_receive(:add_comment).with("ManageIQ/sandbox", @issue.number,  "Applying the following label(s) is not permitted: invalid, invalidagain")
        @client.should_receive(:mark_thread_as_read).with(@issue.number, {"read" => false})

        IssueManager.any_instance.stub(:check_permitted_label => false)
        IssueManager.new.get_notifications

      end

      it "removes labels that do not exist from an issue" do
        ic = double("issue_comment",
          :body       => "@cfme-bot rm_label doesntexist",
          :updated_at => Time.now
        )

        @client.stub(:issue_comments => [ic])
        @client.stub(:label).and_raise(Octokit::NotFound)
        @client.should_receive(:add_comment).with("ManageIQ/sandbox", @issue.number,  "Cannot remove the following label(s) because they are not recognized:  doesntexist")

        @client.should_not_receive(:remove_label)
        @client.should_receive(:mark_thread_as_read).with(@issue.number, {"read" => false})
        IssueManager.new.get_notifications
      end

      it "removes labels that exist from an issue" do
        ic = double("issue_comment",
          :body       => "@cfme-bot rm_label bug",
          :updated_at => Time.now
        )        

        @client.stub(:issue_comments => [ic])
        @client.stub(:label => @label)
        @client.should_receive(:remove_label).with("ManageIQ/sandbox", @issue.number, @label.name)
        @client.should_receive(:mark_thread_as_read).with(@issue.number, {"read" => false})
        IssueManager.new.get_notifications
      end

    end
  end
end
