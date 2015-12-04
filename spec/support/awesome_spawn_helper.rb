require 'awesome_spawn'

module AwesomeSpawn
  module SpecHelper
    def stub_good_run
      stub_run(:good, :run, command, options)
    end

    def stub_bad_run
      stub_run(:bad, :run, command, options)
    end

    def stub_good_run!(command, options = {})
      stub_run(:good, :run!, command, options)
    end

    def stub_bad_run!(command, options = {})
      stub_run(:bad, :run!, command, options)
    end

    private

    def stub_run(mode, method, command, options)
      output = options[:output] || ""
      error  = options[:error]  || (mode == :bad ? "Failure" : "")
      exit_status = options[:exit_status] || (mode == :bad ? 1 : 0)

      params = options[:params]
      command_line = AwesomeSpawn.build_command_line(command, params)

      args = [command]
      args << {:params => params} if params

      result = CommandResult.new(command_line, output, error, exit_status)
      if method == :run! && mode == :bad
        error_message = "#{command} exit code: #{exit_status}"
        error = CommandResultError.new(error_message, result)
        expect(AwesomeSpawn).to receive(method).with(*args).and_raise(error)
      else
        expect(AwesomeSpawn).to receive(method).with(*args).and_return(result)
      end
      result
    end
  end
end

Object.include AwesomeSpawn::SpecHelper
