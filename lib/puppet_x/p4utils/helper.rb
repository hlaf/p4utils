module P4Utils

  class Helper

    P_KEY = 'Protections'
    T_KEY = 'Triggers'
    T_TYPES = ['archive','auth-check','auth-check-sso','auth-set','change-submit','change-content','change-commit',
               'change-failed','command','edge-submit','edge-content','fix-add','fix-delete','form-in','form-out','form-save',
               'form-commit','form-delete','journal-rotate','journal-rotate-lock','push-submit','push-content','push-commit',
               'service-check','shelve-submit','shelve-commit','shelve-delete']
    P_MODES = ['list','read','open','write','admin','super','review','=read','=branch','=open','=write']
    P_TYPES = ['user','group']
    U_TYPES = ['service','operator','standard']
    U_AUTH  = ['perforce','ldap']

    # def default_config_file
    #   Puppet.initialize_settings unless Puppet[:confdir]
    #   File.join(Puppet[:confdir], 'vcenter.conf')
    # end

    def initialize(p4config=nil)
      require 'P4'
      if p4config != nil then
        ENV['P4CONFIG'] = p4config
      end
      @p4 = P4.new
      @p4.connect
      begin
        @p4.run_trust('-y')
      rescue P4Exception
        @p4.errors.each { |e| $stderr.puts( e ) }
        raise
      end
    end

    def getInfo
      return @p4.run_info.shift
    end

    def getConfigurables
      return @p4.run('help','configurables')
    end

    def getSettings
      return @p4.run('configure','show')
    end

    def getSetting(name)
      return @p4.run('configure','show',name).shift
    end

    def getSettingValue(name)
      setting = getSetting(name)
      if setting then
        return setting['Value']
      else
        return nil
      end
    end

    def setSetting(name, value)
      @p4.run('configure','set',"#{name}=#{value}")
    end

    def removeSetting(name)
      @p4.run('configure','unset',name)
    end

    def getProtections
      protections = []
      results = @p4.run_protect('-o').shift
      if results && results[P_KEY] then
        results[P_KEY].each_with_index { |line, i|
          (mode,type,name,host,path) = line.split(' ',5)
          protections << { 'mode' => mode, 'type' => type, 'name' => name, 'host' => host, 'path' => path }
        }
      end
      return protections
    end

    def addProtection(mode, type, name, host, path, insertPos=-1)
      raise "invalid mode" if not P_MODES.include?(mode)
      raise "invalid type" if not P_TYPES.include?(type)
      np = { 'mode' => mode, 'type' => type, 'name' => name, 'host' => host, 'path' => path}
      protections = getProtections
      insertPos = -1 if insertPos >= protections.length
      needsSave = false
      if(!protections.include?(np)) then
        protections.insert(insertPos, np)
        needsSave = true
      elsif (protections.index(np) != insertPos) then
        protections.delete(np)
        protections.insert(insertPos, np)
        needsSave = true
      end
      saveProtections(protections) if needsSave
    end

    def removeProtection(mode, type, name, host, path)
      np = { 'mode' => mode, 'type' => type, 'name' => name, 'host' => host, 'path' => path}
      protections = getProtections
      if(protections.include?(np)) then
        protections.delete(np)
        saveProtections(protections)
      end
    end

    def removeUserProtections(userid)
      protections = getProtections
      n = protections.length
      protections.delete_if { |x| x['name'] == userid and x['type'] == 'user' }
      if(protections.length < n) then
        saveProtections(protections)
      end
    end

    def saveProtections(protections)
      form = { P_KEY => [] }
      protections.each { |e|
        form[P_KEY] << "#{e['mode']} #{e['type']} #{e['name']} #{e['host']} #{e['path']}"
      }
      @p4.save_protect(form)
    end

    def getTriggers
      triggers = []
      results = @p4.run_triggers('-o').shift
      if results && results[T_KEY] then
        results[T_KEY].each { |line|
          (name,type,path,command) = line.tokenize
          triggers << { 'name' => name, 'type' => type, 'path' => path, 'command' => command }
        }
      end
      return triggers
    end

    def getTrigger(name)
      triggers = getTriggers
      return triggers.find {|t| t["name"] == name }
    end

    def addTrigger(name, type, path, command)
      raise "invalid type" if not T_TYPES.include?(type)
      nt = { 'name' => name, 'type' => type, 'path' => path, 'command' => command }
      triggers = getTriggers
      if(!triggers.include?(nt)) then
        triggers.push(nt)
        saveTriggers(triggers)
      end
    end

    def updateTrigger(name, type, path, command)
      raise "invalid type" if not T_TYPES.include?(type)
      nt = { 'name' => name, 'type' => type, 'path' => path, 'command' => command }
      triggers = getTriggers
      found = triggers.find {|t| t["name"] == name }
      if found && found != nt then
        triggers.delete_if { |t| t['name'] == name }
        triggers.push(nt)
        saveTriggers(triggers)
      end
    end

    def removeTrigger(name)
      triggers = getTriggers
      n = triggers.length
      triggers.delete_if { |t| t['name'] == name }
      if(triggers.length < n) then
        saveTriggers(triggers)
      end
    end

    def saveTriggers(triggers)
      form = { T_KEY => [] }
      triggers.each { |e|
        form[T_KEY] << "#{e['name']} #{e['type']} #{e['path']} \"#{e['command']}\""
      }
      @p4.save_triggers(form)
    end

    def getUsers
      users = @p4.run_users('-a')
      users.each { |u|
        u.delete("Update")
        u.delete("Access")
        if !u['AuthMethod'] then
          u['AuthMethod'] = getSettingValue('auth.default.method')
        end
      }
      return users
    end

    def getUser(userid)
      users = getUsers
      return users.find {|u| u["User"] == userid }
    end

    def addUser(userid, fullName, email, type = 'standard', auth = getSettingValue('auth.default.method'))
      raise "invalid type" if not U_TYPES.include?("#{type}")
      raise "invalid auth" if not U_AUTH.include?("#{auth}")
      nu = { 'User' => userid, 'FullName' => fullName, 'Email' => email, 'Type' => type, 'AuthMethod' => auth}
      ou = getUser(userid)
      if (!ou) || (ou != nu) then
        @p4.save_user(Hash[ nu.map { |k, v| [k.to_s, v.to_s] } ], '-f')
      end
    end

    def setPassword(userid, password)
      @p4.run_passwd('-P', password, userid)
    end

    def removeUser(userid, cleanProtections = true, cleanGroups = true)
      if getUser(userid) then
        @p4.delete_user('-f', userid)
        if cleanProtections then
          removeUserProtections(userid)
        end
        if cleanGroups then
          groups = getUserGroups(userid)
          groups.each { |g|
            groupRemoveUser(g['Group'], userid)
          }
        end
      end
    end

    def getGroups
      groups = {}
      results = @p4.run_groups()
      results.each { |line|
        group = line['group']
        if !groups.has_key?(group) then
          groups[group] = {}
          groups[group]['maxLockTime'] = line['maxLockTime']
          groups[group]['maxScanRows'] = line['maxScanRows']
          groups[group]['maxResults'] = line['maxResults']
          groups[group]['timeout'] = line['timeout']
          groups[group]['passTimeout'] = line['passTimeout']
          groups[group]['users'] = []
          groups[group]['owners'] = []
          groups[group]['subgroups'] = []
        end
        if line['isUser'] == '1' then
          groups[group]['users'] << line['user']
        end
        if line['isOwner'] == '1' then
          groups[group]['owners'] << line['user']
        end
        if line['isSubGroup'] == '1' then
          groups[group]['subgroups'] << line['user']
        end
      }
      return groups
    end

    def addGroup(groupid,
      maxResults = 'unset',
      maxScanRows = 'unset',
      maxLockTime = 'unset',
      timeout = 43200,
      passTimeout = 'unset',
      owners = [],
      users = [],
      subgroups = [])
      groupList = getGroups.keys
      group = {}
      group['Group'] = groupid
      group['MaxResults'] = maxResults.to_s
      group['MaxScanRows'] = maxScanRows.to_s
      group['MaxLockTime'] = maxLockTime.to_s
      group['Timeout'] = timeout.to_s
      group['PassTimeout'] = passTimeout.to_s
      group['Owners'] = owners if owners.length > 0
      group['Users'] = users if users.length > 0
      group['Subgroups'] = subgroups if subgroups.length > 0
      doSave = true
      if groupList.include?(groupid) then
        if group == getGroup(groupid) then
          doSave = false
        end
      else
      end
      @p4.save_group(group) if doSave
    end

    def getUserGroups(userid)
      groups = []
      results = @p4.run_groups('-u', userid)
      results.each { |line|
        groups << line['group']
      }
      return groups
    end

    def getGroup(groupid)
      groupList = getGroups.keys
      if groupList.include?(groupid) then
        return @p4.run_group('-o',groupid).shift
      else
        return nil
      end
    end

    def groupAddUser(groupid, user)
      group = getGroup(groupid)
      if group then
        do_add = true
        if group.has_key?('Users') then
          do_add = false if group['Users'].include?(user)
        else
          group['Users'] = []
        end
        if do_add then
          group['Users'].push(user)
          @p4.save_group(group)
        end
      end
    end

    def groupRemoveUser(groupid, user)
      group = getGroup(groupid)
      if group then
        if group.has_key?('Users') and group['Users'].include?(user) then
          group['Users'].delete(user)
          @p4.save_group(group)
        end
      end
    end

    def groupAddOwner(groupid, owner)
      group = getGroup(groupid)
      if group then
        do_add = true
        if group.has_key?('Owners') then
          do_add = false if group['Owners'].include?(owner)
        else
          group['Owners'] = []
        end
        if do_add then
          group['Owners'].push(owner)
          @p4.save_group(group)
        end
      end
    end

    def groupRemoveOwner(groupid, owner)
      group = getGroup(groupid)
      if group then
        if group.has_key?('Owners') and group['Owners'].include?(owner) then
          group['Owners'].delete(owner)
          @p4.save_group(group)
        end
      end
    end

    def removeGroup(groupid)
      group = getGroup(groupid)
      if group then
        @p4.delete_group(groupid)
      end
    end

  end

end

class String
  def tokenize
    self.
      split(/\s(?=(?:[^'"]|'[^']*'|"[^"]*")*$)/).
      select {|s| not s.empty? }.
      map {|s| s.gsub(/(^ +)|( +$)|(^["']+)|(["']+$)/,'')}
  end
end
