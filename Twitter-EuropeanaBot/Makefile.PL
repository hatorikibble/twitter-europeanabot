use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'Twitter::EuropeanaBot',
    AUTHOR        => q{Peter Mayr <at.peter.mayr@gmail.com>},
    VERSION_FROM  => 'lib/Twitter/EuropeanaBot.pm',
    ABSTRACT_FROM => 'lib/Twitter/EuropeanaBot.pm',
    ( $ExtUtils::MakeMaker::VERSION >= 6.3002
       ? ( 'LICENSE' => 'perl' )
       : () ),
    EXE_FILES => ['bin/europeanabot'],
    PL_FILES  => {},
    PREREQ_PM => { 'Test::More'        => 0,
                   'Config::Any::JSON' => 0,
                   'File::Slurp'       => 1,
                   'JSON'              => '2.59',
                   'List::Util'        => 0,
                   'Log::Log4perl'     => '1.29',
                   'LWP::Simple'       => 0,
                   'MooseX::Daemonize' => '0.15',
                   'Net::Twitter'      => '4.0',
		   'URI::Escape'       => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES    => 'Twitter-EuropeanaBot-*' },
);
