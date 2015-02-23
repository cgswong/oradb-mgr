require 'easy_type'

module OraUtils
  class OraDaemon < EasyType::Daemon
    include EasyType::Template

    ORACLE_ERROR    = /ORA-.*|SP-.*|SP2-.*/

    def self.run(os_user, sid, username=nil, password=nil, timeout = nil)
      daemon = super(identity(sid, os_user))
      if daemon
        return daemon
      else
        new(os_user, sid, username, password, timeout)
      end
    end

    def initialize(os_user, sid, username, password, timeout = nil)
      @sqlplus    = SqlplusCommand.new(
                        :username => username,
                        :sid      => sid, 
                        :password => password,
                        :os_user  => os_user,
                        :timeout  => timeout)
      @os_user    = @sqlplus.os_user
      @username   = @sqlplus.username
      @password   = @sqlplus.password
      @sid        = @sqlplus.sid
      @timeout    = @sqlplus.timeout
      Puppet.info "Starting the Oracle daemon with os user #{@os_user} on sid #{sid}"
      command = @sqlplus.command_string
      super(self.class.identity(sid,os_user), command, os_user)
      initial_setup
    end

    def execute_sql_command(command, output_file, timeout = nil)
      timeout ||= @timeout
      Puppet.debug "Executing daemonized sql-command #{command}"
      connect_to_oracle
      execute_command template('puppet:///modules/oracle/shared/daemon_execute.sql.erb', binding)
      execute_command "prompt ~~~~COMMAND SUCCESFULL~~~~"
      sync(timeout) {|line| fail "Error in execution of SQL command: #{command}.\nFound error #{line}" if line =~ ORACLE_ERROR}
      File.read(output_file)
    end

    private

      def self.identity(sid, username)
        "ora-#{sid}-#{username}"
      end


      def connect_to_oracle
        Puppet.debug "Connecting to Oracle sid #{@sid} with os_user #{@username}"
        case @username.downcase
        when 'sysdba', 'sysasm'
          execute_command "connect / as #{@username}\;"
        else
          execute_command "connect #{@username}/#{@password};"
        end
      end

      def initial_setup
        execute_command template('puppet:///modules/oracle/shared/setup.sql.erb', binding)
      end

  end
end

