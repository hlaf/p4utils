require File.expand_path(File.join(File.dirname(__FILE__),'..','..','..','puppet_x','p4utils','helper.rb'))

Puppet::Type.type(:p4_protection).provide(:p4ruby) do

  def initialize(value={})
    super(value)
    @property_flush = {}
  end

  def self.instances
    protections = Array.new
    data = P4Utils::Helper.new.getProtections
    data.each_with_index do |e,i|
      line = "#{e['mode']} #{e['type']} #{e['name']} #{e['host']} #{e['path']}"
      protections << new(
        :ensure   => :present,
        :name     => line,
        :position => i
      )
    end
    return protections
  end

  def self.prefetch(resources)
    protections = instances
    resources.keys.each do | name |
      if provider = protections.find{ | s | s.name == name }
        resources[name].provider = provider
      end
    end
  end

  def create
    Puppet.debug("creating new p4_protection resource")
    helper = P4Utils::Helper.new
    (mode,type,name,host,path) = resource[:line].split(' ',5)
    position = -1

    if(resource[:position]) then
      position = resource[:position]
    end

    begin
      helper.addProtection(mode, type, name, host, path, position)
    rescue
      fail("unable to create protection")
    end
  end

  def destroy
    (mode,type,name,host,path) = resource[:line].split(' ',5)
    P4Utils::Helper.new.removeProtection(mode, type, name, host, path)
  end

  def position
    @property_hash[:position]
  end

  def position=(value)
    @property_flush[:position] = value
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def flush
    if(@property_flush.length > 0) then
      if(resource[:position] != @property_hash[:position]) then
        (mode,type,name,host,path) = resource[:line].split(' ',5)
        P4Utils::Helper.new.addProtection(mode, type, name, host, path, resource[:position])
      end
    end
    @property_hash = resource.to_hash
  end

end
