newproperty(:statement) do
  include ::OraUtils::OracleAccess
  include ::EasyType::Helpers

  desc "The sql command to execute"

  #
  # Let the insync? check for the parameter unless
  #
  def insync?(to)
    resource[:unless] ? unless_value? : false
  end

  private

  def unless_value?
    sid = sid_from_resource
    rows = sql resource[:unless], :username => resource.username, :password => resource.password, :sid => sid
    !rows.empty?
  end

end
