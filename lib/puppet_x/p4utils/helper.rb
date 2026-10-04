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
    # p4d's wordings for "that is not this user's password" (or no password
    # is set at all). Anything else is NOT a rejection and is re-raised.
    PASSWORD_REJECTED = /Authentication failed|Password invalid|P4PASSWD\) invalid or unset|no password set/i
    # 'p4 ldap -t' verdicts. A failed bind names the DN the directory
    # refused ("Authentication as <dn> failed. Reason: ..."); the plain
    # form carries no DN.
    LDAP_TEST_PASSED = /Authentication successful/i
    LDAP_BIND_FAILED = /Authentication as\s+(.+?)\s+failed/i
    LDAP_AUTH_FAILED = /Authentication (?:for \S+ )?failed/i

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

    # Set another user's password through the superuser session, answering
    # the two "Enter new password" / "Re-enter new password" prompts of an
    # interactive 'p4 passwd <user>' over the API's input channel. The
    # argument form ('passwd -P') is deliberately not used: p4d rejects it
    # as "not permitted at this server security level" on some servers, and
    # it would carry the password on the command line.
    def set_password(userid, password)
      if userid == @p4.user then
        raise "set_password cannot change the password of the session user '#{userid}' itself (p4d prompts for the old password first)"
      end
      @p4.input = [password, password]
      @p4.run('passwd', userid)
    end

    # Does the server accept +password+ for +userid+?  Probed as +userid+ on
    # a connection of its own (same P4PORT via P4CONFIG), so the superuser
    # session is untouched; 'login -p' only displays a ticket and stores
    # nothing, and the probe's P4TICKETS is an empty scratch file besides.
    # The password travels over the API's prompt channel and neither it nor
    # the displayed ticket is ever logged. A password rejection answers
    # false; any other failure (connection, protections, ...) is raised so a
    # broken probe can never masquerade as a verdict.
    def password_accepted?(userid, password)
      require 'tempfile'
      tickets = Tempfile.new('p4_user_probe')
      tickets.close
      probe = P4.new
      probe.user = userid
      probe.password = password
      probe.ticket_file = tickets.path
      probe.prog = 'puppet-p4_user'
      begin
        probe.connect
        probe.run_trust('-y') if probe.port.start_with?('ssl:')
        result = probe.run_login('-p')
        # A user with no password at all "logs in" without one: that is not
        # the declared password being accepted.
        notes = (Array(result) + probe.warnings).map { |m| m.to_s }
        if notes.any? { |m| m =~ PASSWORD_REJECTED } then
          log_debug("p4d reports no password set for user '#{userid}'")
          return false
        end
        return true
      rescue P4Exception
        # At the default exception level a warning raises too, so read both.
        messages = (probe.errors + probe.warnings).join(' ')
        if messages =~ PASSWORD_REJECTED then
          log_debug("p4d rejected the declared password for user '#{userid}': #{messages}")
          return false
        end
        raise
      ensure
        probe.disconnect if probe.connected?
        tickets.unlink
      end
    end

    def log_debug(message)
      Puppet.debug(message) if defined?(Puppet)
    end

    # Names of the server's LDAP configurations ('p4 ldaps').
    def getLdapNames
      names = []
      @p4.run_ldaps.each { |entry|
        name = entry['name'] || entry['Name']
        raise "unexpected 'p4 ldaps' output: #{entry.inspect}" if name.nil?
        names << name
      }
      return names
    end

    # The spec form of LDAP configuration +name+ ('p4 ldap -o'). For an
    # unknown name the server answers a template, so existence is decided
    # by getLdapNames, not by this.
    def getLdap(name)
      return @p4.run_ldap('-o', name).shift
    end

    # Save an LDAP spec form ('p4 ldap -i'); the whole form, password
    # included, goes over the API's input channel.
    def saveLdap(form)
      @p4.save_ldap(form)
    end

    def deleteLdap(name)
      if getLdapNames.include?(name) then
        @p4.run_ldap('-d', name)
      end
    end

    # Does the directory accept the server's bind for LDAP configuration
    # +name+?  The server tests the configuration itself ('p4 ldap -t'),
    # authenticating +probe_user+ with +probe_password+ (answered over the
    # API's prompt channel); when the configuration's own bind as
    # +bind_dn+ (the live SearchBindDN) is what the directory refuses, the
    # stored SearchPasswd is stale and the answer is false. A refusal that
    # names a different DN is the probe user's own credential failing, not
    # the server's, and is raised; so is any other failure (no directory,
    # no such user, ...), so a broken probe can never masquerade as a
    # verdict. The plain "Authentication failed" without a DN cannot be
    # told apart and counts as a rejection: re-saving the spec is harmless
    # and the caller re-probes afterwards. Neither password is ever logged.
    def ldap_bind_accepted?(name, bind_dn, probe_user, probe_password)
      @p4.input = probe_password
      begin
        result = @p4.run_ldap('-t', probe_user, name)
        notes = (Array(result) + @p4.warnings).map { |m| m.to_s }
        if notes.any? { |m| m =~ LDAP_TEST_PASSED } then
          return true
        end
        raise "'p4 ldap -t #{probe_user} #{name}' gave no verdict: #{notes.join(' ')}"
      rescue P4Exception
        messages = (@p4.errors + @p4.warnings).join(' ')
        if ldap_search_bind_rejected?(messages, bind_dn) then
          log_debug("the directory refused the server's bind for LDAP configuration '#{name}': #{messages}")
          return false
        end
        raise
      end
    end

    def ldap_search_bind_rejected?(messages, bind_dn)
      if messages =~ LDAP_BIND_FAILED then
        failed_dn = $1
        return false if bind_dn.nil?
        return failed_dn.casecmp(bind_dn.to_s) == 0
      end
      return true if messages =~ LDAP_AUTH_FAILED
      return false
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
