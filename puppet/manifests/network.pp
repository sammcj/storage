class ixastorage::network {
  include ixastorage::params

  class { '::network':
    interfaces_hash    => $ixastorage::params::network_settings,
    config_file_notify => undef,
    require            => Package['NetworkManager'],  # Note this is just for ordering, NetworkManager is ensured absent!
  }


## Manage kernel modules at boot

  augeas{ 'lacpmodules' :
    context => '/files/etc/modules',
    changes => [ 'clear bonding', 'clear mii'] ,
  }

  file { '/etc/modprobe.d/bonding.conf':
    ensure => file,
    source => 'puppet:///modules/ixabond/bonding.conf',
    owner  => 'root',
    group  => 'root',
    mode   => 0644,
  }

## Network tuning
## http://www.chelsio.com/wp-content/uploads/resources/T5-Linux-Chelsio-vs-Niantic.pdf

  augeas::sysctl::conf {
    'net.ipv4.tcp_timestamps':     value => '1';
    'net.ipv4.tcp_sack':           value => '0';
    'net.ipv4.tcp_low_latency':    value => '1';
    'net.ipv4.tcp_window_scaling': value => '0';
    'net.ipv4.tcp_dsack':          value => '0';
    'net.ipv4.tcp_tw_reuse':       value => '1';
    'net.ipv4.tcp_tw_recycle':     value => '1';
    'net.core.netdev_max_backlog': value => '250000';
    'net.core.rmem_max':           value => '524287';
    'net.core.wmem_max':           value => '524287';
    'net.core.rmem_default':       value => '524287';
    'net.core.wmem_default':       value => '524287';
    'net.core.optmem_max':         value => '524287';
    'net.ipv4.tcp_rmem':           value => '4096 87380 524287';
    'net.ipv4.tcp_wmem':           value => '4096 65536 524287';
    'net.ipv4.udp_rmem_min':       value => '8192';
    'net.ipv4.udp_wmem_min':       value => '8192';
  }

## Gross rclocal hacks

  # Remove non-existant bond0 so nagios is happy
  rclocal::script { 'goodbye-bond0':
    priority  => '11',
    content   => "echo '-bond0' >  /sys/class/net/bonding_masters \n",
  }

  # Drop TCP RST packets so brief outages don't cause client abort TODO move to pre-up
  rclocal::script { 'drop-tcp-rst':
    priority  => '10',
    content   => "iptables -A OUTPUT -p tcp --tcp-flags RST RST -j DROP \n",
  }

  file { '/etc/udev/rules.d/45-ixgbe.rules':
    content => "ACTION==\"add\", SUBSYSTEM==\"net\", DRIVERS==\"ixgbe\", RUN+=\"/usr/sbin/ethtool -K %k lro off \"\n",
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    ensure  => absent,
  }

  file { '/etc/udev/rules.d/45-ixgbe-drbd.rules':
    content => "ACTION==\"add\", SUBSYSTEM==\"net\", DRIVERS==\"\", KERNEL==\"drbd\", RUN+=\"/usr/sbin/ethtool -K %k lro off \"\n",
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }

  file { '/etc/udev/rules.d/45-ixgbe-storage.rules':
    content => "ACTION==\"add\", SUBSYSTEM==\"net\", DRIVERS==\"\", KERNEL==\"storage\", RUN+=\"/usr/sbin/ethtool -K %k lro off \"\n",
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }




}