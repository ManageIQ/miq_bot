require "thread"
require "active_support/core_ext/module/delegation"
require "active_support/concern"

module MiqToolsServices
  module ServiceMixin
    extend ActiveSupport::Concern

    included do
      # Hide new in favor of using .call with block to force synchronization
      private_class_method :new
    end

    module ClassMethods
      def call(*args)
        raise "no block given" unless block_given?
        synchronize { yield new(*args) }
      end

      private

      def mutex
        @mutex ||= Mutex.new
      end

      def synchronize
        mutex.synchronize { yield }
      end
    end

    def delegate_to_service(method_name, *args)
      service.send(method_name, *args)
    end

    def method_missing(method_name, *args)
      delegate_to_service(method_name, *args)
    end

    def respond_to_missing?(*args)
      service.respond_to?(*args)
    end
  end
end
