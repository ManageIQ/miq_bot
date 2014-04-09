require 'spec_helper'

describe CFMEToolsServices::MiniGit do
  let(:service) { double("git service") }

  before do
    described_class.any_instance.stub(:service => service)
  end

  def with_service
    described_class.call("/path/to/repo") { |git| yield git }
  end

  it_should_behave_like "ServiceMixin service"

  context ".bugzilla_ids" do
    it "with no bugs" do
      message = <<-EOF
This is a commit message
      EOF

      expect(service).to receive(:show).and_return("#{message}\n")

      with_service do |git|
        expect(git.bugzilla_ids("HEAD")).to eq([])
      end
    end

    it "with one bug" do
      message = <<-EOF
This is a commit message

https://bugzilla.redhat.com/show_bug.cgi?id=123456
      EOF

      expect(service).to receive(:show).and_return("#{message}\n")

      with_service do |git|
        expect(git.bugzilla_ids("HEAD")).to eq([123456])
      end
    end

    it "with multiple bugs" do
      message = <<-EOF
This is a commit message

https://bugzilla.redhat.com/show_bug.cgi?id=123456
https://bugzilla.redhat.com/show_bug.cgi?id=345678
      EOF

      expect(service).to receive(:show).and_return("#{message}\n")

      with_service do |git|
        expect(git.bugzilla_ids("HEAD")).to eq([123456, 345678])
      end
    end
  end

  context "native git method" do
    it "#checkout" do
      expect(service).to receive(:checkout).with("master").and_return("Switched to branch 'master'\n")
      with_service do |git|
        expect(git.checkout("master")).to eq "Switched to branch 'master'"
      end
    end
  end

  it "#new_commits" do
    expect(service).to receive(:rev_list).and_return(<<-EOGIT)
03168b97d19a2f7954e5b29a5cb18862e707ab6c
7575fbbc4919aa64ea34c30102964b6ca6523707
    EOGIT

    with_service do |git|
      expect(git.new_commits("e1512e6acff33bd02c7db928812db8dd8ac4c8d6")).to eq [
        "03168b97d19a2f7954e5b29a5cb18862e707ab6c",
        "7575fbbc4919aa64ea34c30102964b6ca6523707"
      ]
    end
  end

  it "#commit_message" do
    expect(service).to receive(:show).and_return("log_message\n")

    with_service do |git|
      expect(git.commit_message("03168b97d19a2f7954e5b29a5cb18862e707ab6c")).to eq "log_message"
    end
  end

  context "#ref_name" do
    it "on a named ref" do
      expect(service).to receive(:rev_parse).and_return("master\n")

      with_service do |git|
        expect(git.ref_name("123abc")).to eq "master"
      end
    end

    it "on an unnamed ref" do
      expect(service).to receive(:rev_parse).and_return("\n")

      with_service do |git|
        expect(git.ref_name("123abc")).to eq "123abc"
      end
    end
  end

  context "#current_branch" do
    it "on a named ref" do
      expect(service).to receive(:rev_parse).and_return("master\n")

      with_service do |git|
        expect(git.current_branch).to eq "master"
      end
    end

    it "on an unnamed ref" do
      expect(service).to receive(:rev_parse).and_return("HEAD\n")
      expect(service).to receive(:rev_parse).and_return("123abc\n")

      with_service do |git|
        expect(git.current_branch).to eq "123abc"
      end
    end
  end

  it "#current_ref" do
    expect(service).to receive(:rev_parse).and_return("123abc\n")

    with_service do |git|
      expect(git.current_ref).to eq "123abc"
    end
  end

  it "#branches" do
    expect(service).to receive(:branch).and_return(<<-EOGIT)
* master
  branch1
  branch2
    EOGIT

    with_service do |git|
      expect(git.branches).to eq %w{master branch1 branch2}
    end
  end

  it "#diff_details" do
    expect(service).to receive(:diff).with("--patience", "-U0", "--no-color", "6c4a4487~..6c4a4487").and_return(<<-EOGIT)
diff --git a/new_file.rb b/new_file.rb
new file mode 100644
index 0000000..b4c1281
--- /dev/null
+++ b/new_file.rb
@@ -0,0 +1,39 @@
+class SomeClass
+end
+
diff --git a/changed_file.rb b/changed_file.rb
index 4f807bb..57e5993 100644
--- a/changed_file.rb
+++ b/changed_file.rb
@@ -29,0 +30 @@ def method1
+    x = 1
@@ -30,0 +32 @@ def method2
+    x = 2
@@ -68,3 +69,0 @@ def method 3
-    if x == 1
-      x = 3
-    end
    EOGIT

    with_service do |git|
      expect(git.diff_details("6c4a4487")).to eq(
        "new_file.rb"     => [1, 2, 3],
        "changed_file.rb" => [30, 32]
      )
    end
  end

  it ".pr_branch" do
    expect(described_class.pr_branch(133)).to eq "pr/133"
  end

  it "#pr_branch" do
    with_service do |git|
      expect(git.pr_branch(133)).to eq "pr/133"
    end
  end

  it ".pr_number" do
    expect(described_class.pr_number("pr/133")).to eq 133
  end

  it "#pr_number" do
    with_service do |git|
      expect(git.pr_number("pr/133")).to eq 133
    end
  end

  context ".pr_branch?" do
    it "with a pr branch" do
      expect(described_class.pr_branch?("pr/133")).to be_true
    end

    it "with a regular branch" do
      expect(described_class.pr_branch?("master")).to be_false
    end
  end

  context "#pr_branch?" do
    it "with pr branch" do
      with_service do |git|
        expect(git.pr_branch?("pr/133")).to be_true
      end
    end

    it "with regular branch" do
      with_service do |git|
        expect(git.pr_branch?("master")).to be_false
      end
    end

    it "with no branch and current branch is a pr branch" do
      described_class.any_instance.stub(:current_branch => "pr/133")
      with_service do |git|
        expect(git.pr_branch?).to be_true
      end
    end

    it "with no branch and current branch is a regular branch" do
      described_class.any_instance.stub(:current_branch => "master")
      with_service do |git|
        expect(git.pr_branch?).to be_false
      end
    end
  end

  context "#update_pr_branch" do
    it "with pr branch" do
      expect(service).to receive(:fetch).with("-fu", "upstream", "refs/pull/133/head:pr/133").and_return("\n")
      expect(service).to receive(:reset).with("--hard").and_return("\n")

      with_service { |git| git.update_pr_branch("pr/133") }
    end

    it "with no branch and on a pr branch" do
      described_class.any_instance.stub(:current_branch => "pr/133")
      expect(service).to receive(:fetch).with("-fu", "upstream", "refs/pull/133/head:pr/133").and_return("\n")
      expect(service).to receive(:reset).with("--hard").and_return("\n")

      with_service { |git| git.update_pr_branch }
    end
  end

  context "#create_pr_branch" do
    it "with pr branch" do
      expect(service).to receive(:fetch).with("-fu", "upstream", "refs/pull/133/head:pr/133").and_return("\n")
      expect(service).to receive(:reset).with("--hard").and_return("\n")

      with_service { |git| git.create_pr_branch("pr/133") }
    end
  end
end
