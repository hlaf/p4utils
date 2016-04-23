$p4config = '/tmp/p4config.txt'

p4utils::config { $p4config:
  p4port     => 'ssl::1666',
  p4user     => 'p4admin',
  p4password => 'SuperSecret',
  fileowner  => 'alan',
  filegroup  => 'staff',
}

P4_trigger {
  ensure   => present,
  p4config => $p4config,
  require  => P4utils::Config[$p4config],
}

p4_trigger { 'trigger1':
  type    => 'change-commit',
  path    => '//depot/my/path/...',
  command => '/p4/common/triggers/test.sh %change%',
}

p4_trigger { 't8':
  type    => 'form-out',
  path    => 'client',
  command => '/p4/common/triggers/genclient.sh',
}
