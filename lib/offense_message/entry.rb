class OffenseMessage
  class Entry
    attr_reader :severity, :message, :group, :locator

    SEVERITY = {
      :error   => ":bomb: :boom: :fire: :fire_engine:",
      :warn    => ":warning:",
      :high    => ":exclamation:",
      :low     => ":grey_exclamation:",
      :unknown => ":grey_question:",
    }.freeze

    def initialize(severity, message, group = nil, locator = nil)
      raise ArgumentError, "severity must be one of #{SEVERITY.keys.join(", ")}" unless SEVERITY.key?(severity)
      raise ArgumentError, "message is required" if message.blank?

      @severity = severity
      @message  = message
      @group    = group
      @locator  = locator
    end

    def <=>(other_line)
      sort_attributes <=> other_line.sort_attributes
    end

    def to_s
      ["- [ ] #{SEVERITY[severity]}", locator, message].compact.join(" - ")
    end

    protected

    def sort_attributes
      [group.to_s, order_severity, locator.to_s, message.to_s]
    end

    private

    def order_severity
      SEVERITY.keys.index(severity)
    end
  end
end
