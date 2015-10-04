#!/usr/bin/perl

use Getopt::Long;

my $ME = $0;

END {
  defined fileno STDOUT or return;
  close STDOUT and return;
  warn "$ME: failed to close standard output: $!\n";
  $? ||= 1;
}

# Get the program name from $0 and strip directory names
$_=$0;
s/.*\///;
my $pname = $_;

$opt_o = 'reset';       # Default fence action
$opt_s = 'stonith';     # Default fence binary
$opt_t = 'none';        # Default fence type
$extra_args = '-E';

sub usage
{
    print "Helper that presents a RHCS-style interface for Linux-HA stonith plugins\n\n";
    print "Should never need to use invoked by the user directly\n\n";
    print "\n";
    print "Usage: $pname [options]\n";
    print "\n";
    print "Options:\n";
    print "  -h               usage\n";
    print "  -t <sub agent>   sub agent\n";
    print "  -n <name>        nodename\n";
    print "  -o <string>      Action:  on | off | reset (default) | stat | hostlist\n";
    print "  -s <stonith>     stonith command\n";
    print "  -q               quiet mode\n";
    print "  -V               version\n";

    exit 0;
}

sub print_metadata
{
print '<?xml version="1.0" ?>
<resource-agent name="fence_pcmk" shortdesc="Helper that presents a RHCS-style interface for Linux-HA stonith plugins" >
<longdesc>
Should never need to use invoked by the user directly and should only
be configured in cluster.conf, not directly in Pacemaker.
</longdesc>
<vendor-url>http://www.clusterlabs.org</vendor-url>
<parameters>
        <parameter name="action" unique="1" required="1">
                <getopt mixed="-o &lt;action&gt;" />
                <content type="string" default="disable" />
                <shortdesc lang="en">Fencing Action</shortdesc>
        </parameter>
        <parameter name="port" unique="1" required="1">
                <getopt mixed="-n &lt;id&gt;" />
                <content type="string"  />
                <shortdesc lang="en">Physical plug number or name of virtual machine</shortdesc>
        </parameter>
        <parameter name="help" unique="1" required="0">
                <getopt mixed="-h" />
                <content type="string"  />
                <shortdesc lang="en">Display help and exit</shortdesc>
        </parameter>
</parameters>
<actions>
        <action name="enable" />
        <action name="disable" />
        <action name="reboot" />
        <action name="off" />
        <action name="on" />
        <action name="status" />
        <action name="metadata" />
</actions>
</resource-agent>
';
}

sub fail
{
  ($msg) = @_;
  print $msg."\n" unless defined $opt_q;
  $t->close if defined $t;
  exit 1;
}

sub fail_usage
{
  ($msg)=@_;
  print STDERR $msg."\n" if $msg;
  print STDERR "Please use '-h' for usage.\n";
  exit 1;
}

sub version
{
  print "1.0.0\n";

  exit 0;
}

sub get_options_stdin
{
    my $opt;
    my $line = 0;
    while( defined($in = <>) )
    {
        $_ = $in;
        chomp;

  # strip leading and trailing whitespace
        s/^\s*//;
        s/\s*$//;

  # skip comments
        next if /^#/;

        $line+=1;
        $opt=$_;
        next unless $opt;

        ($name,$val)=split /\s*=\s*/, $opt, 2;

        if ( $name eq "" )
        {  
           print STDERR "parse error: illegal name in option $line\n";
           exit 2;
  }
  
        # DO NOTHING -- this field is used by fenced
  elsif ($name eq "agent" ) {} 

  elsif ($name eq "plugin" ) 
  { 
      $opt_t = $val;
  } 
        elsif ($name eq "option" || $name eq "action" )
        {
            $opt_o = $val;
        }
  elsif ($name eq "nodename" ) 
  {
            $opt_n = $val;
      $ENV{$name} = $val;
        } 
  elsif ($name eq "stonith" ) 
  {
            $opt_s = $val;
        }
  else 
  {
      $ENV{$name} = $val;
  }

    }
}

######################################################################33
# MAIN

if (@ARGV > 0) {
    GetOptions("t=s"=>\$opt_t,
         "n=s"=>\$opt_n,
         "o=s"=>\$opt_o,
         "s=s"=>\$opt_s,
         "q"  =>\$opt_q,
         "V"  =>\$opt_V,
         "version"  =>\$opt_V,
         "help"  =>\$opt_h,
         "h"  =>\$opt_h) || fail_usage;
    foreach (@ARGV) {
  print "$_\n";
    }
#   getopts("ht:n:o:s:qV") || fail_usage ;
    
   usage if defined $opt_h;
   version if defined $opt_V;

   fail_usage "Unknown parameter." if (@ARGV > 0);
}

get_options_stdin();

if ((defined $opt_o) && ($opt_o =~ /metadata/i)) {
    print_metadata();
    exit 0;
}

$opt_o=lc($opt_o);
fail "failed: unrecognised action: $opt_o"
    unless $opt_o =~ /^(on|off|reset|reboot|stat|status|monitor|list|hostlist|poweroff|poweron)$/;

if ( $pid=fork() == 0 )
{
   if ( $opt_o eq "reboot" ) 
   {
       $opt_o="reset";
   } 
   elsif ( $opt_o eq "poweron" ) 
   {
       $opt_o="on";
   }
   elsif ( $opt_o eq "poweroff" ) 
   {
       $opt_o="off";
   }

   if ( $opt_o eq "hostlist"|| $opt_o eq "list" )
   {
       exec "$opt_s -t $opt_t $extra_args -l" or die "failed to exec \"$opt_s\"\n";
   }
   elsif ( $opt_o eq "monitor" || $opt_o eq "stat" || $opt_o eq "status" ) 
   {
       print "Performing: $opt_s -t $opt_t -S\n" unless defined $opt_q;
       exec "$opt_s -t $opt_t $extra_args -S" or die "failed to exec \"$opt_s\"\n";
   }
   else
   {
       print "Performing: $opt_s -t $opt_t -T $opt_o $opt_n\n" unless defined $opt_q;
       fail "failed: no plug number" unless defined $opt_n;
       exec "$opt_s -t $opt_t $extra_args -T $opt_o $opt_n" or die "failed to exec \"$opt_s\"\n";
   }
}

wait;
$status=$?/256;

print (($status == 0 ? "success":"failed") . ": $opt_n $status\n")
   unless defined $opt_q;

exit ($status == 0 ? 0 : 1 );
