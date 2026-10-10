
Puppet::Type.newtype(:p4_protection) do
  desc <<-'ENDOFDESC'
  Manages Perforce protection entries.

  Example usage:

  p4_setting { 'write group admins //depot/...':
    position => 4,
  }

  ENDOFDESC

  ensurable

  newparam(:line, :namevar => true) do
   desc "P4 protection entry - must be unique"
   munge do |v|
     v.strip.gsub(/\s+/, ' ')
   end
  end

  newparam(:p4config) do
    desc "location of the p4config file"
    configfile = nil
    # validate the p4config parameter, if passed to the resource
    validate do |value|
      configfile = value
    end
    # if no parameter passed, check for the default configfile
    if !configfile then
      defaultcfg = File.join(Puppet[:confdir], 'p4config.txt')
      if File.exists?(defaultcfg) then
        configfile = defaultcfg
      end
    end
    # set the P4CONFIG environment variable if a configfile exists
    if configfile then
      ENV['P4CONFIG'] = configfile
    end
  end

  newproperty(:position) do
    desc "Position of the entry in the protections table. 0 is the top; higher
      numbers are lower. -1 (the default) is a SENTINEL meaning 'append at the
      end' (the last row), NOT a literal slot -- and an explicit index at or
      past the end of the table is clamped to the end by the provider, so it is
      treated the same way. An explicit in-range index is compared literally.
      Comparing the sentinel against the live slot number the provider reports
      is what made every converge report false drift and re-save the table."
    defaultto (-1)
    munge do |v|
      case v
      when Integer
        v
      when String
        Integer(v)
      else
        raise ArgumentError, "Invalid value #{v.inspect}."
      end
    end

    # -1 ('append at end') is never a real index, so a literal compare against
    # the slot number the provider reports can never match and the entry churns
    # every run. Treat the sentinel -- and an index at/past the end, which the
    # writer clamps to the end -- as "must be the last row"; everything else is
    # a literal slot comparison. The table size comes from the provider, which
    # captures it at prefetch (nil when there is no prefetched data, e.g. a
    # resource being created -- fall back to a literal compare then).
    def insync?(is)
      desired = should
      count = resource.provider.respond_to?(:protection_count) ? resource.provider.protection_count : nil
      if desired == -1 || (!count.nil? && desired >= count)
        return !count.nil? && is == (count - 1)
      end
      is == desired
    end
  end

end
