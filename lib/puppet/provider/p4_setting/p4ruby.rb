require File.expand_path(File.join(File.dirname(__FILE__),'..','..','..','puppet_x','p4utils','helper.rb'))

Puppet::Type.type(:p4_setting).provide(:p4ruby) do

  def initialize(value={})
    super(value)
    @property_flush = {}
  end

  def self.instances
    settings = Array.new
    p4settings = P4Utils::Helper.new.getSettings
    p4settings.each do |s|
      settings << new(
        :ensure => :present,
        :state  => s['Type'].split[0],
        :name   => s['Name'],
        :value  => s['Value'],
      )
    end
    return settings
  end

  def self.prefetch(resources)
    settings = instances
    resources.keys.each do | name |
      if provider = settings.find{ | s | s.name == name }
        resources[name].provider = provider
      end
    end
  end

  def create
    Puppet.debug("creating new p4_setting resource")
    helper = P4Utils::Helper.new
    name = resource[:name]
    value = ''

    if(resource[:value]) then
      value = resource[:value]
    end

    begin
      helper.setSetting(name, value)
    rescue
      fail("unable to set #{name}")
    end
  end

  def destroy
    name = resource[:name]
    P4Utils::Helper.new.removeSetting(name)
  end

  def state
    @property_hash[:state]
  end

  def value
    @property_hash[:value]
  end

  def value=(passed_value)
    @property_flush[:value] = passed_value
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def flush
    if(@property_flush.length > 0) then
      P4Utils::Helper.new.setSetting(resource[:name], resource[:value])
    end
    @property_hash = resource.to_hash
  end
end
