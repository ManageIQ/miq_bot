module GithubService
  module Commands
    class Base
      module CommandMethods
        def register_as(command_name)
          CommandDispatcher.register_command(command_name, self)
        end
        alias alias_as register_as
      end

      class << self
        def inherited(subclass)
          subclass.extend(CommandMethods)

          class_name = subclass.to_s.demodulize
          unless class_name == 'Base'
            subclass.register_as(class_name.underscore)
          end
        end

        def execute!(*args)
          new.execute!(*args)
        end
      end

      attr_reader :issue

      def initialize(issue)
        @issue = issue
      end

      def execute!(command_issuer:, value:)
        raise NotImplementedError
      end
    end
  end
end
