# rubocop:disable Style/NumericLiterals

describe PivotalService do
  describe ".ids_in_git_commit_message" do
    it "with direct story url" do
      url = "https://www.pivotaltracker.com/story/show/137739189"
      expect(described_class.ids_in_git_commit_message(url)).to eq [137739189]
    end

    it "with abbreviated direct story url" do
      url = "https://pivotaltracker.com/story/show/137739189"
      expect(described_class.ids_in_git_commit_message(url)).to eq [137739189]
    end

    it "with project's story url" do
      url = "https://www.pivotaltracker.com/n/projects/1953721/stories/137739189"
      expect(described_class.ids_in_git_commit_message(url)).to eq [137739189]
    end

    it "with abbreviated project's story url" do
      url = "https://pivotaltracker.com/n/projects/1953721/stories/137739189"
      expect(described_class.ids_in_git_commit_message(url)).to eq [137739189]
    end

    it "with multiple urls" do
      message = <<-EOMSG
Some commit message

https://www.pivotaltracker.com/story/show/137739189
https://www.pivotaltracker.com/story/show/137739190
EOMSG
      expect(described_class.ids_in_git_commit_message(message)).to eq [137739189, 137739190]
    end

    it "with duplicate urls" do
      message = <<-EOMSG
Some commit message

https://www.pivotaltracker.com/story/show/137739189
https://www.pivotaltracker.com/story/show/137739189
EOMSG
      expect(described_class.ids_in_git_commit_message(message)).to eq [137739189]
    end
  end
end
