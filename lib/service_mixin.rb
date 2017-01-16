require "active_support/core_ext/module/delegation"
require "active_support/concern"

module ServiceMixin
  extend ActiveSupport::Concern

  included do
    # Hide new in favor of using .call with block for consistency with No
    private_class_method :new

    class << self
      attr_accessor :credentials
    end
    delegate :credentials, :to => self
  end

  module ClassMethods
    def call(*options)
      raise "no block given" unless block_given?
      yield new(*options)
    end
  end

  private

  def delegate_to_service(method_name, *args)
    service.send(method_name, *args)
  end

  def method_missing(method_name, *args) # rubocop:disable Style/MethodMissing
    delegate_to_service(method_name, *args)
  end

  def respond_to_missing?(*args)
    service.respond_to?(*args)
  end
end
