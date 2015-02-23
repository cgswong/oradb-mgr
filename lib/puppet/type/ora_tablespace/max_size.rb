# TODO: Check values
newproperty(:max_size) do
  include EasyType

  desc "maximum size for autoextending"

  def munge(size)
    return size if size.is_a?(Numeric)
    case size
    when /^\d+(K|k)$/ then size.chop.to_i * 1024
    when /^\d+(M|m)$/ then size.chop.to_i * 1024 * 1024
    when /^\d+(G|g)$/ then size.chop.to_i * 1024 * 1024 * 1024
    when /^unlimited$/ then size = 'unlimited'
    when /^\d+$/ then size.to_i
    else
      fail('invalid size')
    end
  end


  # TODO: Check why it doesn't return the right values
  to_translate_to_resource do | raw_resource|
    raw_resource.column_data('MAX_SIZE').to_f.to_i
  end

  on_apply do | command_builder|
  	"maxsize #{should}" if resource[:autoextend] == :on
  end

end
