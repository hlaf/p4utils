require File.expand_path(File.join(File.dirname(__FILE__),'..','..','..','puppet_x','p4utils','helper.rb'))

Puppet::Type.type(:p4_group).provide(:p4ruby) do

  def initialize(value={})
    super(value)
    @property_flush = {}
  end

  def self.convert_value_to_label(value)
    if value.to_i == 0
      return 'unset'
    elsif value.to_i == -1
      return 'unlimited'
    else
      return value.to_s
    end
  end

  def self.instances
    groups = Array.new
    p4groups = P4Utils::Helper.new.getGroups
    p4groups.each do |g|
      data = g[1]
      groups << new(
        :ensure      => :present,
        :name        => g[0],
        :maxresults  => convert_value_to_label(data['maxResults']),
        :maxscanrows => convert_value_to_label(data['maxScanRows']),
        :maxlocktime => convert_value_to_label(data['maxLockTime']),
        :timeout     => convert_value_to_label(data['timeout']),
        :passtimeout => convert_value_to_label(data['passTimeout']),
        :owners      => data['owners'],
        :users       => data['users'],
        :subgroups   => data['subgroups']
      )
    end
    return groups
  end

  def self.prefetch(resources)
    catalog = resources[resources.keys.first].catalog
    p4_group_config = catalog.resources.find{|s| s.type == :p4_group}
    ENV['P4CONFIG'] = p4_group_config['p4config']
    groups = instances
    resources.keys.each do | name |
      if provider = groups.find{ | g | g.name == name }
        resources[name].provider = provider
      end
    end
  end

  def create
    Puppet.debug("creating new p4_group resource")
    group = resource[:name]
    users = []
    owners = []
    subgroups = []
    maxlocktime = 'unset'
    maxscanrows = 'unset'
    maxresults = 'unset'
    timeout = 43200
    passtimeout = 'unset'

    if(resource[:users]) then
      users = resource[:users]
    end
    if(resource[:owners]) then
      owners = resource[:owners]
    end
    if(resource[:subgroups]) then
      subgroups = resource[:subgroups]
    end
    if(resource[:maxlocktime]) then
      maxlocktime = resource[:maxlocktime]
    end
    if(resource[:maxscanrows]) then
      maxscanrows = resource[:maxscanrows]
    end
    if(resource[:maxresults]) then
      maxresults = resource[:maxresults]
    end
    if(resource[:timeout]) then
      timeout = resource[:timeout]
    end
    if(resource[:passtimeout]) then
      passtimeout = resource[:passtimeout]
    end

    P4Utils::Helper.new.addGroup(group,
      maxresults,
      maxscanrows,
      maxlocktime,
      timeout,
      passtimeout,
      owners,
      users,
      subgroups)

  end

  def destroy
    group = resource[:name]
    P4Utils::Helper.new.removeGroup(group)
  end

  def maxresults
    @property_hash[:maxresults]
  end

  def maxresults=(value)
    @property_flush[:maxresults] = value
  end

  def maxscanrows
    @property_hash[:maxscanrows]
  end

  def maxscanrows=(value)
    @property_flush[:maxscanrows] = value
  end

  def maxlocktime
    @property_hash[:maxlocktime]
  end

  def maxlocktime=(value)
    @property_flush[:maxlocktime] = value
  end

  def timeout
    @property_hash[:timeout]
  end

  def timeout=(value)
    @property_flush[:timeout] = value
  end

  def passtimeout
    @property_hash[:passtimeout]
  end

  def passtimeout=(value)
    @property_flush[:passtimeout] = value
  end

  def owners
    @property_hash[:owners]
  end

  def owners=(value)
    @property_flush[:owners] = value
  end

  def users
    @property_hash[:users]
  end

  def users=(value)
    @property_flush[:users] = value
  end

  def subgroups
    @property_hash[:subgroups]
  end

  def subgroups=(value)
    @property_flush[:subgroups] = value
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def flush
    if(@property_flush.length > 0) then
      group = resource[:name]
      users = []
      owners = []
      subgroups = []
      maxlocktime = 'unset'
      maxscanrows = 'unset'
      maxresults = 'unset'
      timeout = 43200
      passtimeout = 'unset'

      if(resource[:users]) then
        users = resource[:users]
      end
      if(resource[:owners]) then
        owners = resource[:owners]
      end
      if(resource[:subgroups]) then
        subgroups = resource[:subgroups]
      end
      if(resource[:maxlocktime]) then
        maxlocktime = resource[:maxlocktime]
      end
      if(resource[:maxscanrows]) then
        maxscanrows = resource[:maxscanrows]
      end
      if(resource[:maxresults]) then
        maxresults = resource[:maxresults]
      end
      if(resource[:timeout]) then
        timeout = resource[:timeout]
      end
      if(resource[:passtimeout]) then
        passtimeout = resource[:passtimeout]
      end

      P4Utils::Helper.new.addGroup(group,
        maxresults,
        maxscanrows,
        maxlocktime,
        timeout,
        passtimeout,
        owners,
        users,
        subgroups)
    end
    @property_hash = resource.to_hash
  end

end
