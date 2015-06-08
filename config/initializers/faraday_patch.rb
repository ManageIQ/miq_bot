# Without this change, a connection's header and each request's header
# all reference the same `@names` hash object so any request that modified
# it via delete or other mutating methods, would affect the headers of other
# requests and the connection.
#
# https://github.com/lostisland/faraday/pull/478
require 'faraday/utils'

module Faraday
  module Utils
    class Headers < ::Hash
      # on dup/clone, we need to duplicate @names hash
      def initialize_copy(other)
        super
        @names = other.instance_variable_get(:@names).dup
      end
    end
  end
end
