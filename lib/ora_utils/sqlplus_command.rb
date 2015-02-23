require 'ora_utils/ora_command'

module OraUtils
  class SqlplusCommand < OraUtils::OraCommand

    VALID_OPTIONS = [
      :sid,
      :os_user,
      :password,
      :timeout,
      :username,
      :daemonized
    ]

    attr_reader :daemonized

    def initialize(options = {})
      super('sqlplus -S /nolog ', options, VALID_OPTIONS)
      @daemonized = options.fetch(:daemonized) { true}
    end

  end
end

