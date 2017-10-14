require File.expand_path(File.join(File.dirname(__FILE__),'..','..','..','puppet_x','p4utils','helper.rb'))

Puppet::Type.type(:p4_trigger).provide(:p4ruby) do

  def initialize(value={})
    super(value)
    @property_flush = {}
  end

  def self.instances
    triggers = Array.new
    data = P4Utils::Helper.new.getTriggers
    data.each do |d|
      triggers << new(
        :ensure  => :present,
        :name    => d['name'],
        :type    => d['type'],
        :path    => d['path'],
        :command => d['command']
      )
    end
    return triggers
  end

  def self.prefetch(resources)
    catalog = resources[resources.keys.first].catalog
    p4_trigger_config = catalog.resources.find{|s| s.type == :p4_trigger}
    ENV['P4CONFIG'] = p4_trigger_config['p4config']
    triggers = instances
    resources.keys.each do | name |
      if provider = triggers.find{ | s | s.name == name }
        resources[name].provider = provider
      end
    end
  end

  def create
    Puppet.debug("creating new p4_trigger resource")
    name = resource[:name]
    type = ''
    path = ''
    command = ''

    if(resource[:type]) then
      type = resource[:type]
    end
    if(resource[:path]) then
      path = resource[:path]
    end
    if(resource[:command]) then
      command = resource[:command]
    end

    # begin
      P4Utils::Helper.new.addTrigger(name, type, path, command)
    # rescue Exception => e
    #   fail("unable to create trigger #{name}")
    #   puts e
    # end
  end

  def destroy
    P4Utils::Helper.new.removeTrigger(resource[:name])
  end

  def type
    @property_hash[:type]
  end

  def type=(value)
    @property_flush[:type] = value
  end

  def path
    @property_hash[:path]
  end

  def path=(value)
    @property_flush[:path] = value
  end

  def command
    @property_hash[:command]
  end

  def command=(value)
    @property_flush[:command] = value
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def flush
    if(@property_flush.length > 0) then
      name = resource[:name]
      type = @property_hash[:type]
      path = @property_hash[:path]
      command = @property_hash[:command]
      if(@property_flush[:type]) then
        type = @property_flush[:type]
      end
      if(@property_flush[:path]) then
        path = @property_flush[:path]
      end
      if(@property_flush[:command]) then
        command = @property_flush[:command]
      end
      P4Utils::Helper.new.updateTrigger(name, type, path, command)
    end
    @property_hash = resource.to_hash
  end

end
