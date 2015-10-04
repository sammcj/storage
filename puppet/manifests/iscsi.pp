class ixastorage::iscsi {
  include ixastorage::params

## ConfigFS for LIO iSCSI

  mount { '/sys/kernel/config':
      ensure  => present,
      atboot  => true,
      device  => 'configfs',
      fstype  => 'configfs',
      require => Package['targetcli'],
  }

  # Force targetcli to NOT create default portal, or else our more specific ones fail
  rclocal::script { 'dont-add-default-portal':
    priority  => '12',
    content   => "targetcli set global auto_add_default_portal=false \n",
    notify    => Exec['dont-add-default-portal'],
    require   => Package['targetcli'],
  }

  exec { 'dont-add-default-portal': # so it works without a reboot
    command     => 'targetcli set global auto_add_default_portal=false',
    refreshonly => true,
    require     => Package['targetcli'],
  }

  file { '/etc/modprobe.d/scsi_mod.conf':
    ensure  => file,
    content => 'options scsi_mod use_blk_mq=Y',
    owner   => 'root',
    group   => 'root',
    mode    => 0644,
  }

}