use Test::More qw(no_plan);

use App::Daemon qw(daemonize cmd_line_parse);
use File::Temp qw(tempfile);
use Fcntl qw/:flock/;

my $appname = 'this_is_such_a_cool_progname_I_AM_UNIQUE';
#my($pf, $pidfile) = tempfile(UNLINK => 1);
#my($lf, $logfile) = tempfile(UNLINK => 1);
#my($of, $outfile) = tempfile(UNLINK => 1);
#my($ef, $errfile) = tempfile(UNLINK => 1);
my($pf, $pidfile) = tempfile();
my($lf, $logfile) = tempfile();
my($of, $outfile) = tempfile();
my($ef, $errfile) = tempfile();

# pidfile should not exists at first start
close $pf;
unlink $pidfile;

# Turdix locks temp files, so unlock them just in case
flock $lf, LOCK_UN;
flock $of, LOCK_UN;
flock $ef, LOCK_UN;

# Ignore childs / zombies
$SIG{CHLD} = 'IGNORE';

ok(1, "loaded ok");
ok(!-e $pidfile, "pidfile not exists");

$App::Daemon::background = 1;
$App::Daemon::appname    = $appname;
$App::Daemon::pidfile    = $pidfile;
$App::Daemon::logfile    = $logfile;

# check start
if( fork() ) {
    ok(1, "start forked");
    sleep(1); # give the child some time
}
else {
    @ARGV = ();
    daemonize();
    sleep(1) while($^T + 60 > time());
    exit;
}

open PIDFILE, "<$pidfile" or die($!);
my $pid = <PIDFILE>;
chomp $pid;
close PIDFILE;

ok($pid, "daemon pid found");

# check log message
open FILE, "<$logfile" or die($!);
my $data = join '', <FILE>;
close FILE;

like($data, qr/^[0-9 :\/]+Process ID is $pid$/m, "log message: pid");
like($data, qr/^[0-9 :\/]+Written to $pidfile$/m, "log message: pidfile");

# check status message after start
if( fork ) {
    ok(1, "status forked");
    sleep(1);
}
else {
    open(STDOUT, ">$outfile") or die($!);
    @ARGV = qw(status);
    daemonize();
    exit;
}
open FILE, "<$outfile" or die($!);
my $data = join '', <FILE>;
close FILE;

like($data, qr/^Pid file:\s+$pidfile$/m, "status message: pidfile");
like($data, qr/^Pid in file:\s+$pid$/m, "status message: pid");
like($data, qr/^Running:\s+yes$/m, "status message: running");
like($data, qr/^Name match:\s+1$/m, "status message: match one process");
like($data, qr/^\s+$appname$/m, "status message: match appname");

# check stop
if( fork ) {
    ok(1, "stop forked");
    sleep(1); # give the child some time
}
else {
    @ARGV = qw(stop);
    daemonize();
    exit;
}

# check status message after stop
if( fork ) {
    ok(1, "status forked");
    sleep(1);
}
else {
    open(STDOUT, ">$outfile") or die($!);
    @ARGV = qw(status);
    daemonize();
    exit;
}
open FILE, "<$outfile" or die($!);
my $data = join '', <FILE>;
close FILE;

like($data, qr/^Pid file:\s+$pidfile$/m, "status message: pidfile");
like($data, qr/^No pidfile found$/m, "status message: no pidfile");
like($data, qr/^Name match:\s+0$/m, "status message: match none process");


