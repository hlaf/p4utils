$p4config = '/tmp/p4config.txt'

p4utils::config { $p4config:
  p4port     => 'ssl::1666',
  p4user     => 'p4admin',
  p4password => 'SuperSecret',
  fileowner  => 'alan',
  filegroup  => 'staff',
}

P4_user {
  ensure   => present,
  p4config => $p4config,
  require  => P4utils::Config[$p4config],
}

p4_user { 'alan':
  email    => 'alan@host.com',
  fullname => 'Alan Petersen',
  type     => 'standard',
  password => 'testpass',
}

p4_user { 'operator':
  email    => 'operator@host.com',
  fullname => 'IT Operations',
  type     => 'operator',
  password => 'operP@SS',
}

p4_user { 'repluser':
  email    => 'repl@host.com',
  fullname => 'Replication Service User',
  type     => 'service',
  password => 'serviceP@SS',
}
