class ixastorage::ssdtune::vm inherits ixastorage::ssdtune {

  ## noop,readahead,rotational off
  file { '/etc/udev/rules.d/95-xentweaks.rules':
    ensure  => present,
    content => "ACTION==\"add|change\" SUBSYSTEM==\"block\", DRIVERS==\"\", KERNEL==\"xvd[a-z]\", ATTR{queue/rotational}==\"0\", ATTR{queue/rq_affinity}=\"2\", ATTR{queue/scheduler}=\"noop\", ATTR{queue/read_ahead_kb}=\"2048\", ATTR{queue/nr_requests}=\"4096\"\n",
    notify  => Exec['udevtrigger'],
  }

  file { '/etc/udev/rules.d/54-drbd.rules':
    ensure  => present,
    content => "ACTION==\"add|change\" SUBSYSTEM==\"block\", DRIVERS==\"\", KERNEL==\"drbd*\", ATTR{queue/rotational}==\"0\", ATTR{queue/rq_affinity}=\"2\", ATTR{queue/nr_requests}=\"4096\"\n",
    notify  => Exec['udevtrigger'],
  }

  file { '/etc/udev/rules.d/56-dm.rules':
    ensure  => present,
    content => "ACTION==\"add|change\", SUBSYSTEM==\"block\", DRIVERS==\"\", KERNEL==\"dm-*\", ATTR{queue/rotational}==\"0\", ATTR{queue/rq_affinity}=\"2\", ATTR{queue/nr_requests}=\"4096\"\n",
    notify  => Exec['udevtrigger'],
  }

  exec { 'udevtrigger':
    command     => '/sbin/udevadm control --reload-rules && /sbin/udevadm trigger',
    refreshonly => true,
    user        => root,
    require     => File['/etc/udev/rules.d/95-xentweaks.rules'],
  }

##################
##   UNTESTED   ##
##################


  # Increase the maximum number of concurrent (non-blocking) async IO requests allowed from 64K to 1M
  augeas::sysctl::conf { 'fs.aio-max-nr':  value => '262144'; }


}