use Test::More tests => 27;

use App::Daemon qw(daemonize cmd_line_parse);
use File::Temp qw(tempfile tmpnam);
use Fcntl qw/:flock/;

my $appname = 'appname_for_testing_with_pid_from_testscript_'.$$;
my $pidfile = tmpnam();

my($lf, $logfile) = tempfile(UNLINK => 1);
my($of, $outfile) = tempfile(UNLINK => 1);
my($ef, $errfile) = tempfile(UNLINK => 1);

# Turdix locks temp files, so unlock them just in case
flock $lf, LOCK_UN;
flock $of, LOCK_UN;
flock $ef, LOCK_UN;

# Ignore childs / zombies
$SIG{CHLD} = 'IGNORE';

# send all error to a file
open(STDERR, ">$errfile");

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

    # dont let the childs removing the pidfile
    if( !fork() ) {
        die("I am a dying child");
        exit;
    }
    if( !fork() ) {
        exit; # I am a exiting child
    }
    # start simple child
    # TODO a forked daemonchild should change his name!
    if( !fork() ) {
        $0 = $appname."_child_fork";
        sleep(1) while($^T + 60 > time());
        exit;
    }
    sleep(1) while($^T + 60 > time());
    exit;
}

open PIDFILE, "<$pidfile";
my $pid = <PIDFILE>;
chomp $pid;
close PIDFILE;

ok($pid, "daemon pid found");

# check status message after start
if( fork ) {
    ok(1, "status forked");
    sleep(1);
}
else {
    open(STDOUT, ">$outfile");
    @ARGV = qw(status);
    daemonize();
    exit;
}
open FILE, "<$outfile";
my @data = <FILE>;
close FILE;

is(scalar(@data), 5, "status message: lines") or diag(@data);
like($data[0], qr/^Pid file:\s+$pidfile$/, "status message: pidfile");
like($data[1], qr/^Pid in file:\s+$pid$/, "status message: pid");
like($data[2], qr/^Running:\s+yes$/, "status message: running");
like($data[3], qr/^Name match:\s+1$/, "status message: match one process");
like($data[4], qr/^\s+$appname$/, "status message: match appname");

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
    open(STDOUT, ">$outfile");
    @ARGV = qw(status);
    daemonize();
    exit;
}
open FILE, "<$outfile";
my @data = <FILE>;
close FILE;

is(scalar(@data), 3, "status message: lines") or diag(@data);
like($data[0], qr/^Pid file:\s+$pidfile$/, "status message: pidfile");
like($data[1], qr/^No pidfile found$/, "status message: no pidfile");
like($data[2], qr/^Name match:\s+0$/, "status message: match none process");

# fakestart
my $fakepid;
if( $fakepid = fork ) {
    ok(1, "fakestart forked");
    sleep(1);
}
else {
    open FILE, ">$pidfile";
    print FILE "$$\n";
    close FILE;
    $SIG{INT} = sub { exit; };
    sleep(1) while($^T + 60 > time());
    exit;
}

# fakestop
if( fork ) {
    ok(1, "fakestop forked");
    sleep(1);
}
else {
    @ARGV = qw(stop);
    daemonize();
    exit;
}

ok(kill(0, $fakepid), "stop dont kill fakedaemon") and kill(2, $fakepid);
ok(!-e $pidfile, "stop deleted fakepidfile");

# check log message
open FILE, "<$logfile";
my @data = <FILE>;
close FILE;

is(scalar(@data), 3, "log message: lines") or diag(@data);
like($data[0], qr/^[0-9 :\/]+Process ID is $pid$/, "log message: pid");
like($data[1], qr/^[0-9 :\/]+Written to $pidfile$/, "log message: pidfile");
like($data[2], qr/^[0-9 :\/]+Stopping Process with ID $pid$/, "log message: stopping");

# nothing was send to STDERR?
open FILE, "<$errfile";
my @data = <FILE>;
close FILE;

is(scalar @data, 1, "stderr message: lines") or diag(@data);
like($data[0], qr/^Daemon\.pm-[0-9]+: Daemon not running or name not match, removing pidfile$/, "stderr message: fakestop");
