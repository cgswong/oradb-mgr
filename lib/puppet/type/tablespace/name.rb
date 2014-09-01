newparam(:name) do
  include EasyType
  include EasyType::Validators::Name
  include EasyType::Mungers::Upcase
  desc "The tablespace name"

  isnamevar

  to_translate_to_resource do | raw_resource|
    sid = raw_resource.column_data('SID').upcase
    tablespace_name = raw_resource.column_data('TABLESPACE_NAME').upcase 
    "#{sid}/#{tablespace_name}"
  end

end

