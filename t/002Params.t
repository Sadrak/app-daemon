use Test::More tests => 4;

use App::Daemon qw(daemonize cmd_line_parse);
use File::Temp qw(tempfile);
use Fcntl qw/:flock/;

my($fh, $tempfile) = tempfile();
my($pf, $pidfile) = tempfile();

# Turdix locks temp files, so unlock them just in case
flock $fh, LOCK_UN;
flock $pf, LOCK_UN;

ok(1, "loaded ok");

open(STDERR, ">$tempfile");

@ARGV = ();
$App::Daemon::background = 0;
$App::Daemon::pidfile    = $pidfile;
daemonize();

ok(1, "running in foreground");

open PIDFILE, "<$pidfile";
my $pid = <PIDFILE>;
chomp $pid;
close PIDFILE;

is($pid, $$, "check pid");

open FILE, "<$tempfile";
my $data = join '', <FILE>;
close FILE;

like($data, qr/Written to $pidfile/, "log message");
