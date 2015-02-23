require_relative '../spec_helper_acceptance'
require_relative '../support/shared_acceptance_specs'


describe 'ora_database' do

  it_behaves_like "an ensurable resource", {
    :resource_name      => 'ora_database',
    :present_manifest   => <<-EOS,

    ora_database{extra: 
      ensure    =>'present',
      oracle_base     => '/opt/oracle',
      oracle_home     => '/opt/oracle/app/11.04',
      control_file    => 'reuse',
      undo_tablespace => {
        name    => 'UNDOTBS'
      },
    }

    EOS
    :absent_manifest    => <<-EOS,
    ora_database{extra: 
      ensure    =>'absent',
    }
    EOS
  }
end
