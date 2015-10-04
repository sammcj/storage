class ixastorage::ssdtune::server inherits ixastorage::ssdtune {

  ## noop,readahead,rotational off
  file { '/etc/udev/rules.d/52-ssd.rules':
    ensure  => present,
    content => "ACTION==\"add|change\", KERNEL==\"sd[a-z]\", ATTR{queue/rotational}==\"0\", ATTR{queue/scheduler}=\"noop\", ATTR{queue/read_ahead_kb}=\"4096\", ATTR{queue/nr_requests}=\"4096\"\n",
    notify  => Exec['udevtrigger'],
  }

  file { '/etc/udev/rules.d/51-nvme.rules':
    ensure  => present,
    content => "ACTION==\"add|change\", KERNEL==\"nvme[0-9]n[0-9]\", ATTR{queue/rotational}==\"0\", ATTR{queue/rq_affinity}=\"2\", ATTR{queue/scheduler}=\"noop\", ATTR{queue/read_ahead_kb}=\"0\"\n",
    notify  => Exec['udevtrigger'],
  }

  file { '/etc/udev/rules.d/54-drbd.rules':
    ensure  => present,
    content => "ACTION==\"add|change\", KERNEL==\"drbd*\", ATTR{queue/rotational}==\"0\", ATTR{queue/rq_affinity}=\"2\", ATTR{queue/scheduler}=\"noop\", ATTR{queue/read_ahead_kb}=\"0\"\n",
    notify  => Exec['udevtrigger'],
  }

  file { '/etc/udev/rules.d/56-dm.rules':
    ensure  => present,
    content => "ACTION==\"add|change\", KERNEL==\"dm-*\", ATTR{queue/rotational}==\"0\", ATTR{queue/rq_affinity}=\"2\", ATTR{queue/scheduler}=\"noop\", ATTR{queue/read_ahead_kb}=\"0\"\n",
    notify  => Exec['udevtrigger'],
  }

  file { '/etc/udev/rules.d/53-mdadm.rules':
    ensure  => present,
    content => "ACTION==\"add|change\", KERNEL==\"md*\", ATTR{queue/rotational}==\"0\", ATTR{queue/rq_affinity}=\"2\", ATTR{queue/scheduler}=\"noop\", ATTR{queue/read_ahead_kb}=\"0\"\n",
    notify  => Exec['udevtrigger'],
  }

  # exec { 'udevtrigger':
  #   command     => '/sbin/udevadm trigger',
  #   refreshonly => true,
  # }

  # Increase the maximum number of concurrent (non-blocking) async IO requests allowed from 64K to 1M
  augeas::sysctl::conf { 'fs.aio-max-nr':  value => '1048576'; }

  # Fix bug for NVMe Hotplug
  exec { 'enable-pcie_bus_perf':
    command => "sed -i 's/GRUB_CMDLINE_LINUX=\"\(.*\)\"/GRUB_CMDLINE_LINUX=\"\1 pci=pcie_bus_safe\"/' /etc/default/grub",
    unless  => "grep -q \"pci=pcie_bus_safe\" /etc/default/grub",
    notify  => Exec['grub2-mkconfig'],
  }

#   pcie_bus_tune_off [X86] Disable PCI-E MPS turning and using
#       the BIOS configured MPS defaults.
#   pcie_bus_safe [X86] Use the smallest common denominator MPS
#       of the entire tree below a root complex for every device
#       on that fabric. Can avoid inconsistent mps problem caused
#       by hotplug.
#   pcie_bus_perf [X86] Configure pcie device MPS to the largest
#       allowable MPS based on its parent bus.Improve performance
#       as much as possible.
#   pcie_bus_peer2peer  [X86] Make the system wide MPS the smallest
#       possible value (128B).This configuration could prevent it
#       from working by having the MPS on one root port different
#       than the MPS on another.

## Setup LVM with discard for SSDs

  file { '/etc/lvm':
    ensure => directory,
  }

  file { '/etc/lvm/lvm.conf':
    ensure    => present,
    content   => template('ixastorage/lvm.conf.erb'),
    owner     => 'root',
    group     => 'root',
    mode      => '0644',
    require   => file['/etc/lvm'],
  }

## Ensure nvme loads before LVM on boot
  file { '/etc/dracut.conf':
    ensure  => file,
    content => "add_drivers+=\"nvme\"",
    notify  => Exec['grub2-mkconfig'],
  }

  # Update SMARTs database
  cron { 'update_smart_drivedb':
    command  => 'http_proxy=http://proxy:3128 /usr/sbin/update-smart-drivedb',
    user     => 'root',
    month    => '*',
    monthday => '3',
    hour     => '11',
    minute   => '0',
  }


}