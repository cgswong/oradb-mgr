require 'ora_utils/ora_command'

module OraUtils
  class SrvctlCommand < OraCommand

    def initialize(options = {})
      super(:srvctl, options)
    end
  end
end

