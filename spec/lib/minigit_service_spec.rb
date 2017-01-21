require 'spec_helper'

describe MiqToolsServices::MiniGit do
  let(:service) { double("git service") }

  before do
    described_class.any_instance.stub(:service => service)
  end

  def with_service
    described_class.call("/path/to/repo") { |git| yield git }
  end

  it_should_behave_like "ServiceMixin service"

  context ".clone" do
    let(:command) { "git clone" }
    let(:params)  { ["git@example.com:org/repo.git", "destination_dir"] }

    it "when it succeeds" do
      result = stub_good_run!(command, :params => params)
      expect(STDERR).to receive(:puts).with("+ #{result.command_line}")
      expect(STDERR).to receive(:puts)

      expect(described_class.clone(*params)).to be true
    end

    it "when it fails" do
      result = stub_bad_run!(command, :params => params)
      expect(STDERR).to receive(:puts).with("+ #{result.command_line}")

      require 'minigit' # To bring in the classes for testing
      expect { described_class.clone(*params) }.to raise_error(MiniGit::GitError)
    end
  end

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

  context "#diff_details" do
    it "parses the diff contents" do
      expect(service).to receive(:diff).with("--patience", "-U0", "--no-color", "6c4a4487~...6c4a4487").and_return(<<-EOGIT)
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

    it "on a single commit" do
      expect(service).to receive(:diff).with("--patience", "-U0", "--no-color", "6c4a4487~...6c4a4487").and_return("")

      with_service do |git|
        git.diff_details("6c4a4487")
      end
    end

    it "with a destination branch" do
      expect(service).to receive(:diff).with("--patience", "-U0", "--no-color", "master...6c4a4487").and_return("")

      with_service do |git|
        git.diff_details("master", "6c4a4487")
      end
    end
  end

  context "#diff_file_names" do
    it "parses the output" do
      expect(service).to receive(:diff).with("--name-only", "6c4a4487~...6c4a4487").and_return(<<-EOGIT)
/path/to/file/a.rb
/path/to/file/b.rb
    EOGIT

      with_service do |git|
        expect(git.diff_file_names("6c4a4487")).to eq [
          "/path/to/file/a.rb",
          "/path/to/file/b.rb"
        ]
      end
    end

    it "on a single commit" do
      expect(service).to receive(:diff).with("--name-only", "6c4a4487~...6c4a4487").and_return("")

      with_service do |git|
        git.diff_file_names("6c4a4487")
      end
    end

    it "with a destination branch" do
      expect(service).to receive(:diff).with("--name-only", "master...6c4a4487").and_return("")

      with_service do |git|
        git.diff_file_names("master", "6c4a4487")
      end
    end
  end

  it ".pr_branch" do
    expect(described_class.pr_branch(133)).to eq "prs/133/head"
  end

  it "#pr_branch" do
    with_service do |git|
      expect(git.pr_branch(133)).to eq "prs/133/head"
    end
  end

  it ".pr_number" do
    expect(described_class.pr_number("prs/133/head")).to eq 133
  end

  it "#pr_number" do
    with_service do |git|
      expect(git.pr_number("prs/133/head")).to eq 133
    end
  end

  context "#remotes" do
    it "with single" do
      allow(service).to receive(:remote).and_return("origin")
      with_service do |git|
        expect(git.remotes).to eq(["origin"])
      end
    end

    it "with multiple" do
      allow(service).to receive(:remote).and_return("origin\nupstream")
      with_service do |git|
        expect(git.remotes).to eq(["origin", "upstream"])
      end
    end
  end

  context "#fetches" do
    it "without pr fetcher" do
      allow(service).to receive(:config).with("--get-all", "remote.origin.fetch").and_return("+refs/heads/*:refs/remotes/origin/*")
      with_service do |git|
        expect(git.fetches("origin")).to eq(["+refs/heads/*:refs/remotes/origin/*"])
      end
    end

    it "with pr fetcher" do
      allow(service).to receive(:config).with("--get-all", "remote.origin.fetch").and_return("+refs/heads/*:refs/remotes/origin/*\n+refs/pull/*:refs/prs/*")
      with_service do |git|
        expect(git.fetches("origin")).to eq(["+refs/heads/*:refs/remotes/origin/*", "+refs/pull/*:refs/prs/*"])
      end
    end
  end

  context "#ensure_prs_refs" do
    it "without pr fetcher will create it" do
      allow_any_instance_of(described_class).to receive(:remote).and_return("origin")
      allow_any_instance_of(described_class).to receive(:fetches).with("origin").and_return(["+refs/heads/*:refs/remotes/origin/*"])

      expect_any_instance_of(described_class).to receive(:config).with("--add", "remote.origin.fetch", "+refs/pull/*:refs/prs/*")

      with_service(&:ensure_prs_refs)
    end

    it "with pr fetcher will not create it" do
      allow_any_instance_of(described_class).to receive(:remote).and_return("origin")
      allow_any_instance_of(described_class).to receive(:fetches).with("origin").and_return(["+refs/heads/*:refs/remotes/origin/*", "+refs/pull/*:refs/prs/*"])

      expect_any_instance_of(described_class).not_to receive(:config)

      with_service(&:ensure_prs_refs)
    end
  end
end
