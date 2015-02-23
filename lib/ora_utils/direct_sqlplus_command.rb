require 'ora_utils/sqlplus_command'

module OraUtils
  class DirectSqlplusCommand < OraUtils::SqlplusCommand

    def execute(arguments)
      options = {:failonfail => true}
      value = ''
      command = "su - #{@os_user} -c \"#{command_string(arguments)}\""
      within_time(@timeout) do
        Puppet.debug "Executing #{@command} command: #{arguments} on #{@sid} as #{os_user}, connected as #{username}"
        value = Puppet::Util::Execution.execute(command, options)
      end
      value
    end


  end
end

