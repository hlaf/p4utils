# p4utils

#### Table of Contents

1. [Overview](#overview)
1. [Setup - The basics of getting started with p4utils](#setup)
    * [Setup requirements](#setup-requirements)
    * [Beginning with p4utils](#beginning-with-p4utils)
1. [Usage - Information about the classes ](#usage)
1. [Limitations - OS compatibility, etc.](#limitations)

## Overview

A set of custom types that can be used to manage a Perforce instance. The defined type `p4utils::config`
manages a P4CONFIG file, which can then be used by the custom files.

A P4CONFIG file can be managed using the `p4utils::config` defined type. The `p4utils` class is provided as a convenience for creating configuration files. Configuration file definitions can 
be passed to the class with the config parameter, or this can
be provided as data in hiera.

For example, the hieradata for a config file in the default location might look like:

~~~
p4utils::config:
  /etc/puppetlabs/puppet/p4config.txt:
    p4port: ssl::1666
    p4user: p4admin
    p4password: AdminP@SS
    p4client: tmpclient
    fileowner: perforce
    filegroup: perforce
~~~

**NOTE**: The class does not manage parent directories, users
or groups, so those should be managed independently of this 
module.

## Setup

### Requirements

* The P4Ruby API must be installed. The p4utils class also requires some stdlib functions.

### Beginning with p4utils

The very basic steps needed for a user to get the module up and running.

If your most recent release breaks compatibility or requires particular steps
for upgrading, you may wish to include an additional section here: Upgrading
(For an example, see http://forge.puppetlabs.com/puppetlabs/firewall).

## Usage

### `p4utils` class
There is one class defined in this module, which acts as a wrapper
for the `p4utils::config` defined resource. This class takes a `config` parameter, which should be a hash, and then performs
`create_resources(p4utils::config, $config)`.

#### Example Usage
In hiera, you could define

~~~
---
p4utils::config:
	main_server:
		configfile: /etc/puppetlabs/puppet/main_p4config.txt
		p4port: ssl:main:1666
		p4user: super
		p4password: secretPass
		p4tickets: /etc/puppetlabs/puppet/p4tickets.txt
		p4trust: /etc/puppetlabs/puppet/p4trust.txt
	secondary_server:
		configfile: /etc/puppetlabs/puppet/secondary_p4config.txt
		p4port: ssl:second.example.com:1666
		p4user: p4admin
		p4password: adminPass
		p4tickets: /etc/puppetlabs/puppet/p4tickets.txt
		p4trust: /etc/puppetlabs/puppet/p4trust.txt
~~~

and then simply declare the p4utils class

`include p4utils`

And this would define two Perforce configuration files on the node.

### `p4utils::config` defined resource
This defined resource can be used to manage a configuration file on the node. Use of this defined type is optional, but it is expected that P4CONFIG information will be passed to the custom types/providers so they can communicate with the Perforce service.

The custom types/providers included in this module are used to
manage various aspects of the Perforce server's configuration.

#### Parameters

* `configfile` -- the path to the configuration file. Defaults to  `$title`.
* `p4port` -- the P4PORT. Defaults to `1666`.
* `p4user` -- the user account with **super** privileges. This account must already exist (i.e. you cannot create it using the `p4_user` type, as the super account is needed to create the users. Chicken and egg! Defaults to `p4admin`.
* `p4password` -- the password associated with the `p4user`. If provided, the defined resource will attempt to login with the account using this password, creating/updating the tickets file. The password is handed to the login script through its environment (`P4PASSWD`), never on the command line, so it shows up neither in `ps` nor in the Puppet log/report when the login fails. This is technically optional, as you can manually login (using `p4 login` on the node) and simply provide the location of the p4tickets file.
* `p4client` -- the client to use to retrive/update files on the server. Currently **optional** because none of the types currently require a configured client. This could change, however, as new types are added.
* `p4tickets` -- the location of the `P4TICKETS` file. Defaults to a p4tickets.txt file in the same directory as the configfile.
* `p4trust` -- the location of the `P4TRUST` file. Defaults to a p4trust.txt file in the same directory as the configfile.
* `fileowner` -- the OS user that will own the `P4CONFIG`, `P4TICKETS` and `P4TRUST` files. Defaults to `root`.
* `filegroup` -- the OS group that will own the `P4CONFIG`, `P4TICKETS` and `P4TRUST` files. Defaults to `root`.
* `filemode` -- the file mode for the `P4CONFIG`, `P4TICKETS` and `P4TRUST` files. Defaults to '0600'.

#### Example Usage

~~~
$p4config = '/tmp/p4config.txt'

p4utils::config { $p4config:
  p4port     => 'ssl::1666',
  p4user     => 'p4admin',
  p4password => 'SuperSecret',
  fileowner  => 'perforce',
  filegroup  => 'perforce',
}
~~~

### `p4_user`
This custom type manages Perforce user accounts. Only the attributes you declare are managed: on every save the provider reads the user's form back from the server and overlays just the declared fields, so an undeclared `type` or `authmethod` -- and anything the type does not model, such as `Reviews` or `JobView` -- keeps its live value. Nothing is guessed from a server default (`auth.default.method` says what a *new* user would get, not what an existing one has).

#### Attributes
* `ensure` -- must be one of `present` or `absent`. Defaults to `present`.
* `name` -- the username. Defaults to `$title`.
* `fullname` -- the full name of the user. This is a required attribute if the user is going to be created.
* `email` -- the email of the user. This is a required field if the user is going to be created.
* `password` -- the user's password. When given it is **enforced**: on every run the provider checks that the server still accepts it for the user (a display-only `p4 login -p` probe, run as the user on a connection of its own) and, if it does not -- wrong password or no password set -- re-sets it through the superuser session with an interactive `p4 passwd <user>` (the `-P` argument form is not used; p4d rejects it at some security levels, and it would expose the password on the command line). The password is a *parameter*, so it never appears as a desired value in events, reports or `--noop` diffs; it only ever travels over the Perforce API's prompt channel. Cannot be combined with `authmethod => ldap`.
* `password_state` -- **derived, do not set**. Present (desired `accepted`) exactly when `password` is given; its current value is `accepted` or `rejected`, so a `password_state changed 'rejected' to 'accepted'` event is the provider re-setting the password. Users managed without a `password` are never probed.
* `type` -- must be one of `standard`, `operator` or `service`. No default: left as the server has it when undeclared (p4d creates a new user as `standard`).
* `authmethod` -- must be one of `perforce` or `ldap`. No default: left as the server has it when undeclared (p4d creates a new user with its `auth.default.method`).
* `p4config` -- used to specify the location of the config file. If not specified, the type will default to `$PUPPET_CONFIG_DIR/p4config.txt`.

#### Example Usage

Managing a user 'bob' with default configuration:

~~~
p4_user { 'bob':
  ensure   => present,
  fullname => 'Bob User',
  email    => 'bob@host.com,
}
~~~

For more information on Perforce users, consult the Perforce documentation (or type `p4 help user`).

### `p4_ldap`
This custom type manages Perforce LDAP configurations (`p4 ldap` specs). Only the attributes you declare are managed; every other field of an existing spec is read back and preserved on each save, so a resource that sets just `host` leaves the bind, group and attribute fields alone.

#### Attributes
* `ensure` -- must be one of `present` or `absent`. Defaults to `present`.
* `name` -- the configuration name. Defaults to `$title`.
* `host`, `port`, `encryption` (`none`, `ssl` or `tls`), `bind_method` (`simple`, `search` or `sasl`), `options`, `simple_pattern`, `search_base_dn`, `search_filter`, `search_scope` (`baseonly`, `children` or `subtree`), `search_bind_dn`, `sasl_realm`, `group_base_dn`, `group_search_filter`, `group_search_scope`, `attribute_uid`, `attribute_name`, `attribute_email` -- the spec fields, one property each (see `p4 help ldap`).
* `search_passwd` -- the password the server binds with as `search_bind_dn`. When given it is **enforced**: on every run the provider has the server test the configuration (`p4 ldap -t <probe_user> <name>`, the probe user's password answered over the API's prompt channel) and, if the directory refuses the server's own bind -- a stale `SearchPasswd`, typically after the bind account's password was rotated -- re-saves the spec with the declared password and tests again, failing loudly if the directory still refuses. It is a *parameter*, so it never appears as a desired value in events, reports or `--noop` diffs; it only ever travels inside the spec form over the Perforce API, never on a command line. Requires `probe_user` and `probe_password`, and is required by a declared `search_bind_dn`.
* `probe_user` / `probe_password` -- a directory user (any LDAP user the configuration can authenticate; it needs no Perforce access) and its password, used only for the `search_passwd` test above. A refusal that names the probe user rather than the server's bind DN fails the resource instead of being mistaken for a stale `SearchPasswd`.
* `search_passwd_state` -- **derived, do not set**. Present (desired `accepted`) exactly when `search_passwd` is given; its current value is `accepted` or `rejected`, so a `search_passwd_state changed 'rejected' to 'accepted'` event is the provider re-saving the spec. Configurations managed without a `search_passwd` are never tested.
* `p4config` -- used to specify the location of the config file. If not specified, the type will default to `$PUPPET_CONFIG_DIR/p4config.txt`.

#### Example Usage

~~~
p4_ldap { 'corp-ldap':
  ensure         => present,
  host           => 'ldap.example.com',
  port           => '389',
  encryption     => 'tls',
  bind_method    => 'search',
  search_base_dn => 'ou=users,dc=example,dc=com',
  search_filter  => '(&(objectClass=posixAccount)(uid=%user%))',
  search_scope   => 'subtree',
  search_bind_dn => 'cn=proxy,ou=users,dc=example,dc=com',
  search_passwd  => 'SuperSecret',
  probe_user     => 'bob',
  probe_password => 'BobsSecret',
}
~~~

Enabling a configuration (`auth.ldap.order.N`) and switching users to `authmethod => ldap` are separate steps; see `p4 help ldap`.

### `p4_group`
This custom type manages Perforce groups.

#### Attributes
* `ensure` -- must be one of `present` or `absent`. Defaults to `present`.
* `name` -- the group name. Defaults to `$title`.
* `owners` -- an array listing the owner(s) of the group.
* `users` -- an array listing the member(s) of the group.
* `subgroups` -- an array listing the subgroup(s) of the group.
* `maxlocktime` -- the maximum time that locks will be placed in the Perforce database. Defaults to `unset`.
* `maxresults` -- the maximum number of results returned by a command execution. Defaults to `unset`.
* `maxscanrows` -- the maximum number of rows that will be scanned in the Perforce database. Defaults to `unset`.
* `passtimeout` -- the expiration time for user passwords. Defaults to `unset`.
* `timeout` -- a timeout (in seconds) for login tickets.  Defaults to `43200` (12 hours).
* `p4config` -- used to specify the location of the config file. If not specified, the type will default to `$PUPPET_CONFIG_DIR/p4config.txt`.

#### Example Usage

Managing a group 'admins', owned by 'p4super' with members 'bob' and 'alan':

~~~
p4_group { 'admins':
  ensure      => 'present',
  owners      => ['p4super'],
  users       => ['bob', 'alan'],
}
~~~

For more information on Perforce groups, consult the Perforce documentation (or type `p4 help group`).

### `p4_trigger`
This custom type manages Perforce trigger entries in the triggers table.

#### Attributes
* `ensure` -- must be one of `present` or `absent`. Defaults to `present`.
* `name` -- the trigger name. Defaults to `$title`.
* `type` -- the type of trigger. Valid types are:
	* archive -- external archive access triggers
	* auth-check -- check authentication trigger
	* auth-check-sso -- sso check authentication trigger
	* auth-set -- set authentication trigger
	* change-submit -- pre-submit triggers
	* change-content -- modify content submit triggers
	* change-commit -- post-submit triggers
	* change-failed -- submit failure fires these triggers
	* command -- pre/post user command triggers
	* edge-submit -- Edge Server pre-submit
	* edge-content -- Edge Server content submit
	* fix-add -- pre-add fix triggers
	* fix-delete -- pre-delete fix triggers
	* form-in -- modify form in triggers
	* form-out -- modify form out triggers
	* form-save -- pre-save form triggers
	* form-commit -- post-save form triggers
	* form-delete -- pre-delete form triggers
	* journal-rotate -- post-journal rotation triggers
	* journal-rotate-lock -- blocking journal rotate triggers
	* push-submit -- pre-push triggers
	* push-content -- modify content push triggers
	* push-commit -- post-push triggers
	* service-check -- check auth trigger (service users)
	* shelve-submit -- pre-shelve triggers
	* shelve-commit -- post-shelve triggers
	* shelve-delete -- pre-delete shelve triggers
* `command` -- the full path for the trigger command.
* `path` -- the depot path affected by the trigger.
* `p4config` -- used to specify the location of the config file. If not specified, the type will default to `$PUPPET_CONFIG_DIR/p4config.txt`.

#### Example Usage

Managing a `change-commit` trigger:

~~~
p4_trigger { 'trigger1':
  type    => 'change-commit',
  path    => '//depot/my/path/...',
  command => '/p4/common/triggers/test.sh %change%',
}
~~~

For more information on triggers in Perforce, consult the Perforce documentation (or type `p4 help triggers`).

### `p4_protection`
This custom type manages Perforce protection entries in the protection table.

#### Attributes
* `ensure` -- must be one of `present` or `absent`. Defaults to `present`.
* `line` -- the P4 protection entry - must be unique. Defaults to `$title`.
* `position` -- an integer indicating the position in the protection table. `0` indicates the start of the protection table. Defaults to `-1`, which corresponds to the end of the protections table.
* `p4config` -- used to specify the location of the config file. If not specified, the type will default to `$PUPPET_CONFIG_DIR/p4config.txt`.

#### Example Usage

Managing write permission for the group `admins`:

~~~
p4_protection { 'write group admins * //depot/puppet/...':
  ensure   => 'present',
  position => '4',
}
~~~

For more information on Perforce protections, consult the Perforce documentation (or type `p4 help protect`).

### `p4_setting`
This custom type manages Perforce tuning settings.

- **value**
    Value associated with the setting

#### Attributes
* `ensure` -- must be one of `present` or `absent`. Defaults to `present`.
* `name` -- the P4 configuration setting name - must be unique. Defaults to `$title`.
* `value` -- the value associated with the setting.
* `state` -- **READ ONLY** -- a field indicating the state of the configurable. Possible values are `default`, `environment`, `configure` and `tunable`:
	* `default` - indicates that this value is currenly unconfigured, and is set to the default value.
    * `environment` - indicates that this value is configured via environment variables.
    * `configure` - indicates that the value is a switch that sets functionality on the server, and is configured.
    * `tunable` - indicates that the value is a variable that affects server tuning, and is configured.
* `position` -- an integer indicating the position in the protection table. `0` indicates the start of the protection table. Defaults to `-1`, which corresponds to the end of the protections table.
* `p4config` -- used to specify the location of the config file. If not specified, the type will default to `$PUPPET_CONFIG_DIR/p4config.txt`.

#### Example Usage

Managing the `security` Perforce server setting:

~~~
p4_setting { 'security':
  ensure => 'present',
  value  => '3',
}
~~~

For more information on Perforce settings, consult the Perforce documentation (or type `p4 help configure`). To get a list of all possible configuration settings, type `p4 help configurables`.


## Limitations

I've tested this on CentOS and Ubuntu. The types have also been tested on MacOSX, my development system.


