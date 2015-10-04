# Class: ixastorage::ha
# Corosync / pacemaker Setup

class ixastorage::ha {
  include ixastorage::params
  include corosync::reprobe

  $unicast_addresses=$ixastorage::params::unicast_addresses
  $storage_gateway=$ixastorage::params::network_settings['storage']['gateway']

  # This is useful for the first setup if you want to true or false some values based on if the unit is in production yet
  case $being_setup {
    true: {
      $setup_bool_inverse = false
      $setup_ensure = present
    }
    default: {
      $setup_bool_inverse = true
      $setup_ensure = absent
    }
  }

  file { '/root/cluster_bootstrap.sh':
    ensure => $setup_ensure,
    source => 'puppet:///modules/ixastorage/cluster_bootstrap.sh',
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

#######################################
###     Debugging configuration     ###
#######################################

  # http://blog.clusterlabs.org/blog/2013/pacemaker-logging/
  # Set to 'all' to enable
  augeas { 'PCMK_blackbox':
    context => "/files/etc/sysconfig/pacemaker",
    changes => "set PCMK_blackbox yes",
  }

  # Change log to warn
  augeas { 'PCMK_logpriority':
    context => "/files/etc/sysconfig/pacemaker",
    changes => "set PCMK_logpriority warning",
  }

  # Change debug to off
  augeas { 'PCMK_debug':
    context => "/files/etc/sysconfig/pacemaker",
    changes => "set PCMK_debug off",
  }

#######################################
###     Corosync Configuration      ###
#######################################

  class { 'corosync':
    enable_secauth                      => false,
    multicast_address                   => 'broadcast',
    bind_address                        => '172.30.1.0',
    debug                               => $being_setup,
    force_online                        => false,
    set_votequorum                      => true,
    quorum_members                      => $unicast_addresses,
    two_node                            => true,
    token_retransmits_before_loss_const => '20',
    require                             => [Yumrepo['mrmondo_pacemaker'],Class['ixacommon::redhat::centos7::repos'],Package['lvm2']],
  }

  corosync::service { 'pacemaker':
    version => '1',
  }

  logrotate::rule { 'corosync':
    path          =>  '/var/log/cluster/corosync.log',
    rotate_every  => 'daily',
    rotate        => 7,
    compress      => true,
    delaycompress => true,
    missingok     => true,
    ifempty       => false,
    copytruncate  => true,
    require       => Class['corosync'],
  }

#######################################
###     Pacemaker Global Defaults   ###
#######################################

  cs_property { 'no-quorum-policy':         value => 'ignore' }
  cs_property { 'stonith-enabled':          value => $setup_bool_inverse }
  cs_property { 'cluster-recheck-interval': value => '0' }
  cs_property { 'start-failure-is-fatal':   value => 'false' }
  #cs_property { 'migration-limit':         value => '1' }


  #http://clusterlabs.org/doc/en-US/Pacemaker/1.1/html/Pacemaker_Explained/s-failure-migration.html
  # Indicates that the resource will move to a new node after <migration-threshold> failures and wait <failure-timeout> seconds before failing the resource back.
  #cs_rsc_defaults { 'migration-threshold':  value => '5' }
  #cs_rsc_defaults { 'resource-stickiness':  value => '20' }
  #cs_rsc_defaults { 'allow-migrate':        value => 'true' }
  #cs_rsc_defaults { 'failure-timeout':      value => '15s' }


##################################################
### Services Managed by Pacemaker / Corosync   ###
##################################################

  service { 'target':
    ensure    => undef,
    enable    => false,
    require   => [Package['pacemaker'],Class['corosync'],Class['ixacommon::redhat::centos7::repos']],
  }

  service { 'pacemaker':
    ensure    => undef,
    enable    => true,
    require   => [Package['pacemaker'],Class['corosync'],Class['ixacommon::redhat::centos7::repos']],
  }


#######################################
### Single resources for each host  ###
#######################################

  ## TODO ensure if disabled manually puppet doesn't start

  ## Storage network monitor

  cs_primitive { "ping_gateway":
    primitive_class => 'ocf',
    primitive_type  => 'ping',
    provided_by     => 'pacemaker',
    parameters      => { 'host_list'    => "$storage_gateway",
                         'dampen'       => '20s' },
    operations      => { 'monitor'      => { 'interval' => '10s', 'timeout' => '10s', 'attempts' => '3' } }, # Recommended intervals
    require         => [Cs_property['stonith-enabled'],Service['pacemaker']],
  }

  cs_clone { "ping_gateway-clone":
    primitive       => "ping_gateway",
    require         => [Cs_primitive['ping_gateway'],Service['pacemaker']],
  }


#######################################
### Backup Configuration            ###
#######################################

  cron { 'backup_pacemaker_cib':
    command  => '/usr/sbin/crm configure show > /var/log/cluster/backup_cib_$(date +"\%F").log',
    user     => 'root',
    month    => '*',
    monthday => '*',
    hour     => 7,
    minute   => 0,
  }

  cron { 'backup_mdadm_config':
    command  => '/usr/bin/cat /proc/mdstat > /var/log/cluster/backup_mdadm_$(date +"\%F").log; /usr/sbin/mdadm --detail --scan >> /var/log/cluster/backup_mdadm_$(date +"\%F").log',
    user     => 'root',
    month    => '*',
    monthday => '*',
    hour     => 7,
    minute   => 0,
  }

  logrotate::rule { 'backup_pacemaker_cib':
    path          =>  '/var/log/cluster/backup*.log',
    rotate_every  => 'day',
    rotate        => '90',
    compress      => true,
    delaycompress => true,
    missingok     => true,
    ifempty       => false,
    copytruncate  => true,
    require       => Cron['backup_mdadm_config'],
  }


## Notify if you're shutting down a node without putting it in standby

  file { '/etc/confirmfirst.d':
    ensure  => 'directory',
  }

  file { '/etc/confirmfirst.d/standby-check':
    ensure  => present,
    source  => 'puppet:///modules/ixastorage/standby-check.sh',
    owner   => root,
    group   => root,
    mode    => '0755',
    require => File['/etc/confirmfirst.d'],
  }

}