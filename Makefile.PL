use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'App::Daemon',
    VERSION_FROM      => 'Daemon.pm', # finds $VERSION
    PREREQ_PM         => {
        Log::Log4perl      => "1.0",
        File::Pid          => 0,
        Proc::ProcessTable => 0,
        Getopt::Std        => 0,
        Pod::Usage         => 0,
        File::Basename     => 0,
        Test::More         => 0,
        File::Temp         => 0,
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'Daemon.pm', # retrieve abstract from module
       AUTHOR         => 'Mike Schilli <m@perlmeister.com>') : ()),
);
