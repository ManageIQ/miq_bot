module RuboCop
  module Cop
    module ManageIQ
      class PreferredMethods < Cop
        MSG = "Prefer `%s` over `%s`."

        def on_send(node)
          _receiver, method_name, *_args = *node
          return unless preferred_methods[method_name]
          add_offense(node, :selector,
                      format(MSG,
                             preferred_method(method_name),
                             method_name)
                     )
        end

        private

        def preferred_methods
          {
            :intern => :to_sym
          }
        end

        def preferred_method(method)
          preferred_methods[method.to_sym]
        end
      end
    end
  end
end
