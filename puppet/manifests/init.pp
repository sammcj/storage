# Sets up LVM, mdadm, iSCSI, DRBD, LACP

class ixastorage {
  include ::lvm
  include rclocal
  include ixastorage::ssdtune::server
  include ixastorage::network
  include ixastorage::packages
  include ixastorage::params
  include ixastorage::iscsi
  include ixastorage::ha

  class { 'abrt':
    active                      => true,
    maxcrashreportssize         => '1000',
    dumplocation                => '/var/spool/abrt',
    deleteuploaded              => 'no',
    opengpgcheck                => 'no',
    blacklist                   => ['strace'],
    blacklistedpaths            => ['/usr/share/doc/*'],
    processunpackaged           => 'no',
    abrt_sosreport              => false,
    abrt_backtrace              => 'simple',
  }

  class { 'selinux': mode=>'permissive' }

## Setup RAID
  class { 'ixastorage::mdadm': arrays => $ixastorage::params::storage_group_hash['arrays'] }

## Create the cluster resources / primitives
  create_resources('lvm::volume_group',$ixastorage::params::storage_group_hash['volume_groups'])
  create_resources('ixastorage::drbd',$ixastorage::params::storage_group_hash['drbd'])
  create_resources('ixastorage::ha_resource',$ixastorage::params::storage_group_hash['ha_resources'])
  create_resources('ixastorage::stonith',$ixastorage::params::storage_group_hash['storage_hosts'])

## Setup DRBD

  class { '::drbd':
    require        => [Class['ixastorage::mdadm'],Class['ixacommon::redhat::centos7::repos']],
    service_enable => false,
  }

  exec { 'drbd_reload_conf':
    command     => '/sbin/drbdadm adjust all',
    refreshonly => true,
  }

}