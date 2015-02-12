require 'pathname'
$:.unshift(Pathname.new(__FILE__).dirname.parent.parent)
$:.unshift(Pathname.new(__FILE__).dirname.parent.parent.parent.parent + 'easy_type' + 'lib')
require 'easy_type'
require 'ora_utils/oracle_access'
require 'ora_utils/commands'
require 'ora_utils/ora_tab'
require 'ora_utils/directories'

module Puppet
  newtype(:ora_database) do
    include EasyType
    include ::OraUtils::OracleAccess
    include ::OraUtils::Directories
    include ::OraUtils::Commands

    desc "This resource allows you to manage an Oracle Database."

    set_command([:sql, :remove_directories, :srvctl, :orapwd])

    ensurable

    on_create do | command_builder |
      begin
        @dbname = is_cluster? ? instance_name : name
        create_directories
        create_init_ora_file
        add_oratab_entry
        create_ora_pwd_file(command_builder)

        if is_cluster?
          register_database(command_builder)
          add_instances(command_builder)
          disable_database(command_builder)
        end

        create_stage_1
        create_stage_2
        execute_stage_1( command_builder)
        execute_stage_2( command_builder)
        nil

      rescue => e
        remove_directories
        fail "Error creating database #{name}, #{e.message}"
        nil
      end
    end

    on_modify do | command_builder |
      info "database modification not yet implemented"
      nil
    end

    on_destroy do | command_builder |
      if is_cluster?
        remove_instance_registrations( command_builder)
        remove_database_registration( command_builder)
      end
      statement = template('puppet:///modules/oracle/ora_database/destroy.sql.erb', binding)
      command_builder.add(statement, :sid => name, :daemonized => false)
      command_builder.after('', :remove_directories)
    end

    parameter :name
    parameter :system_password
    parameter :sys_password
    parameter :init_ora_content
    parameter :timeout
    parameter :control_file
    parameter :maxdatafiles
    parameter :maxinstances
    parameter :character_set
    parameter :national_character_set
    parameter :tablespace_type
    parameter :logfile
    parameter :logfile_groups
    parameter :maxlogfiles
    parameter :maxlogmembers
    parameter :maxloghistory
    parameter :archivelog
    parameter :force_logging
    parameter :extent_management
    parameter :oracle_home
    parameter :oracle_base
    parameter :oracle_user
    parameter :install_group
    parameter :autostart
    parameter :default_tablespace
    parameter :datafiles
    parameter :default_temporary_tablespace
    parameter :undo_tablespace
    parameter :sysaux_datafiles
    parameter :spfile_location
    parameter :config_scripts
  
    #
    # When defining a RAC database, these become valuable
    #
    parameter :instances
    parameter :scan_name
    parameter :scan_port
    # -- end of attributes -- Leave this comment if you want to use the scaffolder

    private

    def create_init_ora_file
      File.open(init_ora_file, 'w') do |file| 
        file.write(init_ora_content)
        if is_cluster?
	  instance_names = instances.keys.sort    # sort the keys for ruby 1.8.7 Hash ordering
	  instance_names.each_index do |index|
	    instance = instance_names[index]
	    instance_no = index + 1
	    file.write("#\n")
	    file.write("# Parameters inserted by Puppet ora_database (RAC)\n")
	    file.write("#\n")
	    file.write("#{instance}.instance_number=#{instance_no}\n")
	    file.write("#{instance}.thread=#{instance_no}\n")
	    file.write("#{instance}.undo_tablespace=UNDOTBS#{instance_no}\n")
	  end
        else
	  file.write("#\n")
	  file.write("# Parameters inserted by Puppet ora_database\n")
	  file.write("#\n")
        end
      end      
      owned_by_oracle( init_ora_file)
      Puppet.debug "File #{init_ora_file} created with content"
    end

    def add_oratab_entry
      oratab = OraUtils::OraTab.new
      oratab.ensure_entry(@dbname, oracle_home, autostart)
    end

    def create_ora_pwd_file(command_builder)
      command_builder.add("file=#{oracle_home}/dbs/orapw#{name} force=y password=#{sys_password} entries=20", :orapwd, :sid => @dbname)
    end

    def create_stage_1
      content = template("puppet:///modules/oracle/ora_database/create.sql.erb", binding)
      path = "#{oracle_base}/admin/#{name}/scripts/create.sql"
      File.open(path, 'w') { |f| f.write(content) }
      owned_by_oracle(path)
    end

    def create_stage_2
      case config_scripts.count
	when 1
          config_scripts.each_pair do |script, content|
            path = "#{oracle_base}/admin/#{name}/scripts/#{script}.sql"
            File.open(path, 'w') { |f| f.write(content) }
            owned_by_oracle(path)
          end
        when 2..999
          config_scripts.each do |cs|
            path = "#{oracle_base}/admin/#{name}/scripts/#{cs.keys}.sql"
            File.open(path, 'w') { |f| f.write(cs.values) }
            owned_by_oracle(path)
          end
        end
    end

    def register_database(command_builder)
      command = if spfile_location
        "add database -d #{name} -o #{oracle_home} -n #{name} -m #{name} -p #{spfile_location}/#{name}/spfile#{name}.ora "
      else
        "add database -d #{name} -o #{oracle_home} -n #{name} -m #{name} "
      end
      command_builder.add(command, :srvctl, :sid => @dbname)
    end

    def add_instances(command_builder)
      instances.each do | instance, node|
        command_builder.add("add instance -d #{name} -i #{instance} -n #{node}", :srvctl, :sid => @dbname)
      end
    end

    def disable_database(command_builder)
      command_builder.add("disable database -d #{name}", :srvctl, :sid => @dbname)
    end

    def remove_instance_registrations(command_builder)
      instances.each do | instance, node|
        command_builder.add("remove instance -d #{name} -i #{instance}", :srvctl, :sid => @dbname)
      end
    end

    def remove_database_registration(command_builder)
      command_builder.add("remove database -d #{name}", :srvctl, :sid => @dbname)
    end

    def execute_stage_1( command_builder)
      command_builder.add("@#{oracle_base}/admin/#{name}/scripts/create", :sid => @dbname, :daemonized => false, :timeout => 0)
    end

    def execute_stage_2( command_builder)
      case config_scripts.count
	when 1
          config_scripts.each_pair do |key, content| 
            command_builder.after("@#{oracle_base}/admin/#{name}/scripts/#{key}", :sid => @dbname, :daemonized => false, :timeout => 0)
	  end
	when 2..999
          config_scripts.each do |es| 
            command_builder.after("@#{oracle_base}/admin/#{name}/scripts/#{es.keys}", :sid => @dbname, :daemonized => false, :timeout => 0)
          end
	end
    end

    def instance_name(entry=1)
      "#{name}#{entry}"
    end

    def is_cluster?
      instances.count > 0
    end

    def hostname
      Facter.value('hostname')
    end

    def init_ora_file
      "#{oracle_home}/dbs/init#{@dbname}.ora"
    end

  end
end

