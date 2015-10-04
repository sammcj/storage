class ixastorage::packages {

  package { ['irqbalance','gdisk','fio','numactl','lshw','smartmontools','OpenIPMI','quota','ledmon','mcelog',
             'iftop','iperf','ipmitool','perl-Nagios-Plugin','make','perl-Digest-MD5','lvm2','cifs-utils','python-2.7.5']:
    ensure  => latest,
    require => [Class['ixacommon::redhat::centos7::repos'],Exec['lock_puppet'],Yumrepo['mrmondo_pacemaker']],
  }

  # Required for STONITH
  package { ['cluster-glue','cluster-glue-libs','crmsh','nvme-cli','resource-agents']:
    ensure          => present,
    install_options => [ {'--enablerepo' => 'mrmondo_pacemaker'} ],
    require         => [Yumrepo['mrmondo_pacemaker'],Package['lvm2','python-2.7.5'],Class['ixacommon::redhat::centos7::repos']],
    notify          => Exec['lock_drbd84_utils'],
  }

  # Lock DRBD utils package due to bug in 8.9.3
  exec { 'lock_drbd84_utils':
    command     => '/usr/bin/yum versionlock drbd84-utils-8.9.2',
    unless      => 'grep -q drbd84-utils-8.9.2 /etc/yum/pluginconf.d/versionlock.list',
  }

  # Required for iSCSI
  package { ['scsi-target-utils','targetcli']:
    ensure  => present,
    require => Class['ixacommon::redhat::centos7::repos'],
  }

# Repo for HA packages missing in CentOS 7
  yumrepo { 'mrmondo_pacemaker':
    descr      => 'sams pacemaker packages with legacy stonith plugins',
    enabled    => '1',
    gpgcheck   => '0',
    gpgkey     => 'file:///etc/pki/rpm-gpg/RPM-GPG-KEY-packagecloud_io',
    baseurl    => 'https://packagecloud.io/mrmondo/pacemaker/el/7/x86_64/',
    proxy      => 'https://proxy:3128',
    retries    => '2',
    timeout    => '5',
    priority   => '1',
    protect    => '1',
    mirrorlist => absent,
  }

  #CentOS resource-agents missing anything
  file { '/usr/lib/ocf/resource.d/heartbeat/anything':
    ensure  => present,
    source  => 'puppet:///modules/ixastorage/ha_resource_anything.sh',
    owner   => root,
    group   => root,
    mode    => '0755',
    require => Package['resource-agents'],
  }

  #CentOS resource-agents missing fence_legacy
  file { '/usr/sbin/fence_legacy':
    ensure  => present,
    source  => 'puppet:///modules/ixastorage/fence_legacy.pl',
    owner   => root,
    group   => root,
    mode    => '0755',
    require => Package['resource-agents'],
  }

}
