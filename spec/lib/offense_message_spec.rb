describe OffenseMessage do
  describe "#lines" do
    it "with full entries" do
      message = described_class.new
      message.entries = [
        OffenseMessage::Entry.new(:high, "Message 4", "Group B", "Locator B"),
        OffenseMessage::Entry.new(:high, "Message 3", "Group B", "Locator A"),
        OffenseMessage::Entry.new(:high, "Message 2", "Group A", "Locator B"),
        OffenseMessage::Entry.new(:high, "Message 1", "Group A", "Locator A"),
      ]
      expect(message.lines).to eq([
                                    "**Group A**",
                                    "- [ ] :exclamation: - Locator A - Message 1",
                                    "- [ ] :exclamation: - Locator B - Message 2",
                                    "",
                                    "**Group B**",
                                    "- [ ] :exclamation: - Locator A - Message 3",
                                    "- [ ] :exclamation: - Locator B - Message 4"
                                  ])
    end

    it "with entries - with and without groups" do
      message = described_class.new
      message.entries = [
        OffenseMessage::Entry.new(:high, "Message 4", "Group B", "Locator B"),
        OffenseMessage::Entry.new(:high, "Message 3", "Group B", "Locator A"),
        OffenseMessage::Entry.new(:high, "Message 2", nil, "Locator B"),
        OffenseMessage::Entry.new(:high, "Message 1", nil, "Locator A"),
      ]
      expect(message.lines).to eq([
                                    "- [ ] :exclamation: - Locator A - Message 1",
                                    "- [ ] :exclamation: - Locator B - Message 2",
                                    "",
                                    "**Group B**",
                                    "- [ ] :exclamation: - Locator A - Message 3",
                                    "- [ ] :exclamation: - Locator B - Message 4"
                                  ])
    end
  end
end
