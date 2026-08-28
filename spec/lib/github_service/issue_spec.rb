RSpec.describe GithubService::Issue do
  subject(:issue) { described_class.new(source_issue) }

  let(:fq_repo_name) { "foo/bar" }
  let(:issue_number) { 123 }
  let(:labels) { [] }
  let(:source_issue) do
    double(
      "issue",
      :labels         => labels.map { |label| double(:name => label) },
      :number         => issue_number,
      :repository_url => "https://api.github.com/repos/#{fq_repo_name}",
      :title          => title
    )
  end
  let(:github_client) { double }

  before do
    allow(GithubService).to receive(:service).and_return(github_client)
  end

  describe "#add_label" do
    before do
      allow(github_client).to receive(:add_labels_to_an_issue)
    end

    context "when WIP follows another title tag" do
      let(:title) { "[RFR] [WIP] Fix title" }

      it "does not add another WIP title tag" do
        expect(GithubService).not_to receive(:update_issue)

        issue.add_label("wip")

        expect(github_client).to have_received(:add_labels_to_an_issue).with(fq_repo_name, issue_number, ["wip"])
      end
    end
  end

  describe "#remove_label" do
    let(:labels) { ["wip"] }

    before do
      allow(github_client).to receive(:remove_label)
    end

    context "when WIP follows another title tag" do
      let(:title) { "[RFR] [WIP] Fix title" }

      it "removes only the WIP title tag" do
        expect(GithubService).to receive(:update_issue)
          .with(fq_repo_name, issue_number, {:title => "[RFR] Fix title"})

        issue.remove_label("wip")

        expect(github_client).to have_received(:remove_label).with(fq_repo_name, issue_number, "wip")
      end
    end
  end
end
