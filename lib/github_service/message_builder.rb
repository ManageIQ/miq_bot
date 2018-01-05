module GithubService
  class MessageBuilder < ::MessageCollector
    COMMENT_BODY_MAX_SIZE = 65_535

    def initialize(header = nil, continuation_header = nil)
      super(COMMENT_BODY_MAX_SIZE, header, continuation_header)
    end
  end
end
