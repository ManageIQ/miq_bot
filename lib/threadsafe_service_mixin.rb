module ThreadsafeServiceMixin
  extend ActiveSupport::Concern

  include ServiceMixin

  module ClassMethods
    def call(*args)
      synchronize { super }
    end

    private

    def mutex
      @mutex ||= Mutex.new
    end

    def synchronize
      mutex.synchronize { yield }
    end
  end
end
