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
* `p4password` -- the password associated with the `p4user`. If provided, the defined resource will attempt to login with the account using this password, creating/updating the tickets file. This is technically optional, as you can manually login (using `p4 login` on the node) and simply provide the location of the p4tickets file.
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
This custom type manages Perforce user accounts.

#### Attributes
* `ensure` -- must be one of `present` or `absent`. Defaults to `present`.
* `name` -- the username. Defaults to `$title`.
* `fullname` -- the full name of the user. This is a required attribute if the user is going to be created.
* `email` -- the email of the user. This is a required field if the user is going to be created.
* `password` -- the user's password. Currently this attribute is only used if the user is created.
* `type` -- must be one of `standard`, `operator` or `service`.
* `authmethod` -- must be one of `perforce` or `ldap`. Defaults to `perforce`.
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


