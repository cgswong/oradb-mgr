require 'easy_type'
require 'ora_utils/direct_sqlplus_command'

module OraUtils
  class OraDirect
    include EasyType::Template

    attr_reader :user, :sid, :username, :password

    def self.run(os_user, sid, username='sysdba', password=nil, timeout = nil)
      self.new(os_user, sid, username, password, timeout)
    end

    def initialize(os_user, sid, username, password, timeout)
      @sqlplus    = DirectSqlplusCommand.new(
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
    end

    def execute_sql_command(command, output_file)
      script = command_file( template('puppet:///modules/oracle/shared/direct_execute.sql.erb', binding))
      @sqlplus.execute "@#{script}"
      File.read(output_file)
    end

    private

    def command_file( content)
      command_file = Tempfile.new([ 'command', '.sql' ])
      ObjectSpace.undefine_finalizer(command_file)  # Don't delete the file
      command_file.write(content)
      command_file.close
      FileUtils.chown(@os_user, nil, command_file.path)
      FileUtils.chmod(0644, command_file.path)
      FileUtils.chown(@os_user, nil, command_file.path)
      FileUtils.chmod(0644, command_file.path)
      command_file.path
    end
  end

end
