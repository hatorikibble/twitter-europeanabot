package Twitter::EuropeanaBot;

=head1 NAME

Twitter::EuropeanaBot - The great new Twitter::EuropeanaBot!

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Twitter::EuropeanaBot;

    my $foo = Twitter::EuropeanaBot->new();
    ...

=head2 METHODS

=cut

use strict;
use warnings;
use namespace::autoclean;

use FindBin qw($Bin);
use Log::Log4perl qw( :levels);

use Encode;
use File::Slurp;
use JSON;
use List::Util qw( shuffle);
use LWP::Simple qw(get $ua);
use Net::Twitter;
use POSIX;
use Switch;
use URI::Escape;

use Data::Dumper;

our $VERSION = '1.4';

use Moose;
with
  qw( MooseX::Getopt MooseX::Log::Log4perl MooseX::Daemonize MooseX::Runnable   );

use Moose::Util::TypeConstraints;

subtype 'File', as 'Str',
  where { -e $_ },
  message { "Cannot find any file at $_" };

has 'debug'                   => ( is => 'ro', isa => 'Bool', default  => 0 );
has 'dont_close_all_files'    => ( is => 'ro', isa => 'Bool', default  => 1 );
has 'name'                    => ( is => 'ro', isa => 'Str',  required => 1 );
has 'europeana_api_key'       => ( is => 'ro', isa => 'Str',  required => 1 );
has 'europeana_api_url'       => ( is => 'ro', isa => 'Str',  required => 1 );
has 'twitter_account'         => ( is => 'ro', isa => 'Str',  required => 1 );
has 'twitter_consumer_key'    => ( is => 'ro', isa => 'Str',  required => 1 );
has 'twitter_consumer_secret' => ( is => 'ro', isa => 'Str',  required => 1 );
has 'twitter_access_token'    => ( is => 'ro', isa => 'Str',  required => 1 );
has 'twitter_access_token_secret' =>
  ( is => 'ro', isa => 'Str', required => 1 );
has 'url_shortener'    => ( is => 'ro', isa => 'Str',  required => 1 );
has 'location_file'    => ( is => 'ro', isa => 'File', required => 1 );
has 'nobel_file'       => ( is => 'ro', isa => 'File', required => 1 );
has 'guardian_api_key' => ( is => 'ro', isa => 'Str',  required => 1 );
has 'guardian_api_url' => ( is => 'ro', isa => 'Str',  required => 1 );
has 'user_agent' => ( is => 'ro', isa => 'Str', default => "EuropeanaBot" );
has 'wikipedia_base' =>
  ( is => 'ro', isa => 'Str', default => "http://en.wikipedia.org" );

has 'sleep_time' => ( is => 'ro', isa => 'Int', default => 2000 );

no Moose::Util::TypeConstraints;

Log::Log4perl::init( $Bin . '/logging.conf' );

=head2 run

called by the perl script

=cut

sub run {
    my $self = shift;
    $self->start();
    exit(0);
}

after start => sub {
    my $self       = shift;
    my $result_ref = undef;
    my @seeds      = ();
    my $range      = 100;
    my $random     = undef;

    return unless $self->is_daemon;

    $self->log->info("Daemon started..");

    $self->createTwitterObject();

    #$self->lookForMentions();

    $self->createLocationSeeds();

    $self->createNobelSeeds();

    while (1) {

        # what shall we do? let's roll the dice?
        $random = int( rand($range) );

        # cheat if we have a specific date..

        # Monday Morning, 9 o'clock
        if (
            ( POSIX::strftime( "%u", localtime() ) == 1 )    # Monday
            && ( POSIX::strftime( "%H", localtime() ) eq '09' )
          )
        {
            $random = 101;
        }

        # Friday, 13 o'clock
        if (
            ( POSIX::strftime( "%u", localtime() ) == 5 )    # Friday
            && ( POSIX::strftime( "%H", localtime() ) eq '13' )
          )
        {
            $random = 102;
        }

        # $random = 54;

        eval {
            switch ($random) {
                case [ 0 .. 2 ] { $self->writeHammerTimeTweet(); }
                case [ 3 .. 5 ] {
                    $self->writeUnicornTweet();
                }
                case [ 6 .. 25 ]{ $self->writeLocationTweet(); }
                case [ 26 .. 45 ]{ $self->writeNobelTweet(); }
                case [ 46 .. 75 ] { $self->writeGuardianNewsTweet() };
                case [ 76 .. 95 ] { $self->writeRandomWikipediaTweet(); }
                case [ 96 .. 100 ]{ $self->writeCatTweet(); }

                # special cases
                case 101 { $self->writeMondayTweet(); }
                case 102 { $self->writeFollowFridayTweet(); }

            }
        };
        if ($@) {
            $self->log->error( "Oh problem!: " . $@ );
        }
        else {

            $self->log->debug(
                "I'm going to sleep for " . $self->sleep_time . " seconds.." );
            sleep( $self->sleep_time );
        }

    }

};

after status => sub {
    my $self = shift;
    $self->log->info("Status check..");
};

before stop => sub {
    my $self = shift;
    $self->log->info("Daemon ended..");
};

=head2 createTwitterObject()

authenticate to Twitter and return a C<Net::Twitter>-object

=cut

sub createTwitterObject {
    my $self    = shift;
    my $Twitter = Net::Twitter->new(
        traits              => [qw/API::RESTv1_1/],
        consumer_key        => $self->twitter_consumer_key,
        consumer_secret     => $self->twitter_consumer_secret,
        access_token        => $self->twitter_access_token,
        access_token_secret => $self->twitter_access_token_secret,
    ) || $self->log->logdie("Could not create Twitter-Object: $!");

    $self->{Twitter} = $Twitter;
    $self->log->debug("Twitter Object created");
}

=head2 lookForMentions()

are there any Twitter-Mentions for the Bot

=cut

sub lookForMentions {
    my $self = shift;

    eval {
        my $mentions = $self->{Twitter}->mentions();
        $self->log->info( "Mentions: " . Dumper($mentions) );
    };
    $self->log->debug( "ups:" . $@ );

}

=head2 createLocationSeeds()

reads the contents of C<$self->location_file> 
and creates C<$self->{LocationSeeds}>

=cut

sub createLocationSeeds {
    my $self  = shift;
    my @lines = ();
    my @tmp   = ();

    $self->log->debug( "Creating seeds from file: " . $self->location_file );
    eval { @lines = read_file( $self->location_file ); };
    if ($@) {
        $self->log->error(
            "Cannot read seed_file " . $self->location_file . ": " . $@ );
        return \@lines;
    }
    else {

        #cleanup
        foreach my $line (@lines) {
            chomp($line);

            # 10302,Donnerskirchen,10302,M,7082,
            if ( $line =~ s/^\d+,(.*?),.*?$/$1/ ) {
                push( @tmp, $line );
            }

        }
        @lines = @tmp;
        $self->log->debug( scalar(@lines) . " searchterms generated" );
        $self->{LocationSeeds} = \@lines;
    }

} ## end sub createSeed

=head2 createNobelSeeds()

reads the contents of C<$self->nobel_file> 
and creates C<$self->{NobelSeeds}>

=cut

sub createNobelSeeds {
    my $self = shift;

    my @lines = ();

    $self->log->debug( "Creating seeds from file: " . $self->nobel_file );
    eval { @lines = read_file( $self->nobel_file ); };
    if ($@) {
        $self->log->error(
            "Cannot read seed_file " . $self->nobel_file . ": " . $@ );
        return \@lines;

    }
    else {

        @lines = @lines[ 1 .. $#lines ];

        # we don't need the header..

        $self->log->debug( scalar(@lines) . " searchterms generated" );
        $self->{NobelSeeds} = \@lines;
    }

} ## end sub createSeed

=head2 getEuropeanaResults(Query=>'Linz', Field=>'title', Type=>'IMAGE', Rows=>10)

searches Europeana and returns the first matching Result

Parameters

=over 

=item  * Query

querystring for the search

=item * Field

which index to use

=item * Type

type of result, defaults to  I<IMAGE>

=items * Rows

how many rows should be returned, defaults to C<1>

=back

=cut

sub getEuropeanaResults {
    my ( $self, %p ) = @_;
    my $json_result  = undef;
    my $result_ref   = undef;
    my $query_string = undef;

    $p{Type} = 'IMAGE' unless ( defined( $p{Type} ) );
    $p{Rows} = 1       unless ( defined( $p{Rows} ) );

    $self->log->debug( "Query: " . $p{Query} );

    #build $query_string
    eval {
        $query_string = sprintf( "%s?wskey=%s&rows=%s&qf=TYPE:%s&query=%s:%s",
            $self->europeana_api_url, $self->europeana_api_key, $p{Rows},
            $p{Type}, $p{Field}, uri_escape_utf8( $p{Query} ) );
    };

    if ($@) {
        $self->log->error( "Error while creating query string: " . $@ );
        $result_ref->{Status} = "NotOK";
        $result_ref->{Query}  = $p{Query};
        return $result_ref;
    }

    $self->log->debug( "QueryString is: " . $query_string );
    if ( $json_result = get $query_string) {
        $result_ref = decode_json($json_result);
        $self->log->debug( "Result: " . Dumper( $result_ref->{itemsCount} ) );
        if ( $result_ref->{itemsCount} > 0 ) {

            # custom enrichment
            $result_ref->{Status} = "OK";
            $result_ref->{Query}  = $p{Query};
            return $result_ref;
        }
        else {
            $result_ref->{Status} = "NotOK";
            $result_ref->{Query}  = $p{Query};
            return $result_ref;
        }

    }

}

=head2 post2Twitter(Message=>'So.. you like cats? Here's a picture from #europeana: _URL_', Result=>$result)

posts the result to the twitter account specified by C<$self->twitter_account>

Parameters

=over

=item  * Message

message to post, you can use the following placeholders C<_TITLE_>, C<_YEAR_>,
C<_URL_>

=item  * Result

Europeana Search Result

=back

=cut

sub post2Twitter {
    my ( $self, %p ) = @_;
    my $nt_result = undef;
    my $short_url = undef;
    my $status    = undef;
    my @items     = undef;

    $status = $p{Message};

    if ( defined( $p{Result} ) ) {
        @items = @{ $p{Result}->{items} };

        @items = shuffle @items;

        $short_url = get( $self->url_shortener . $items[0]->{guid} );

        $status =~ s/_TITLE_/$p{Result}->{Query}/;
        $status =~ s/_URL_/$short_url/;

        if ( defined( $items[0]->{year}->[0] ) ) {
            $status =~ s/_YEAR_/$items[0]->{year}->[0]/;

        }
        else {
            $status =~ s/ (from|at) _YEAR_//;

        }
    }

    $status = decode( 'utf8', $status );
    $self->log->info(
        "Posting Status: " . $status . " (" . length($status) . ")" );

    if ( $self->debug == 1 ) {
        $self->log->info("Just kidding! We are in debug mode...");
    }
    else {

        if ( length($status) > 140 ) {
            $self->log->warn("Status is too long!");
        }
        else {

            eval { $nt_result = $self->{Twitter}->update($status); };
            if ($@) {
                $self->logger->error( "Error posting to "
                      . $self->twitter_account . ": "
                      . $@
                      . "!" );

            }
        }

        # $self->log->debug( Dumper($nt_result) );
    }

} ## end sub post2Twitter

=head2 writeLocationTweet()

posts a search result from the Location Tweet file

=cut

sub writeLocationTweet {
    my $self       = shift;
    my $result_ref = undef;
    my @seeds      = shuffle @{ $self->{LocationSeeds} };
    my @messages   = (
        "Hi! I found an image of _TITLE_ from _YEAR_ at \#europeana: _URL_",
        "Oh! _TITLE_ at _YEAR_ from \#europeana: _URL_",
        "Look! A \#europeana Image: _TITLE_ at _YEAR_ _URL_",
"Hi! Are you interested in an \#europeana image of _TITLE_ from _YEAR_? _URL_"
    );
    @messages = shuffle @messages;

    $self->log->debug("I'm gonna tweet about a location!");

    foreach my $term (@seeds) {

        $result_ref = $self->getEuropeanaResults(
            Query => $term,
            Field => 'where',
            Type  => 'IMAGE',
            Rows  => 10
        );
        if ( $result_ref->{Status} eq 'OK' ) {
            $self->post2Twitter(
                Result  => $result_ref,
                Message => $messages[0]
            );

            return;
        }
    }
}

=head2 writeNobelTweet()

posts a search result from the Nobel Prizes Tweet file

=cut

sub writeNobelTweet {
    my $self       = shift;
    my $result_ref = undef;
    my $name       = undef;
    my $w_url      = undef;
    my $w_content  = undef;
    my @fields     = ();
    my @seeds      = shuffle @{ $self->{NobelSeeds} };
    my @messages   = (
"Hi! Did you know _TITLE_ got a Nobel Prize? \#europeana has a picture _URL_",
        "Oh! Nobel Prize for _TITLE_ at _YEAR_! Check out \#europeana: _URL_",
"Look! A \#europeana image of Nobel Prize winner _TITLE_ at _YEAR_: _URL_",
"Hi! Are you interested in an \#europeana image of Nobel Prize winner _TITLE_ from _YEAR_? _URL_"
    );
    @messages = shuffle @messages;

    $self->log->debug("I'm gonna tweet about a Nobel Prize winner!");

    foreach my $item (@seeds) {
        @fields = split( /,/, $item );

        #year,category,overallMotivation,id,firstname,surname,motivation,share

        $fields[4] =~ s/"//g;
        $fields[5] =~ s/"//g;

        $result_ref = $self->getEuropeanaResults(
            Query => "\"" . $fields[4] . " " . $fields[5] . "\"",
            Field => 'title',    # 'who' doesn't find enough
            Type  => 'IMAGE',
            Rows  => 5
        );
        if ( $result_ref->{Status} eq 'OK' ) {

            # is there a Wikipedia Page?
            $w_url =
                $self->wikipedia_base
              . "/wiki/"
              . uri_escape_utf8( $fields[4] ) . "_"
              . uri_escape_utf8( $fields[5] );

            # set UserAgent per API Policy
            # http://www.mediawiki.org/wiki/API#Identifying_your_client
            $ua->agent( $self->user_agent );

            $w_content = get($w_url);

            if ( defined($w_content) ) {
                $messages[0] .=
                  " (#wikipedia:" . get( $self->url_shortener . $w_url ) . ")";
            }
            else {
                $self->log->warn( "Strange no Wikipedia Page? " . $w_url );

            }

            $self->post2Twitter(
                Result  => $result_ref,
                Message => $messages[0]
            );

            return;
        }
    }
}

=head2 writeRandomWikipediaTweet()

posts a search result to a random Wikipedia page

=cut

sub writeRandomWikipediaTweet {
    my $self        = shift;
    my $result_ref  = undef;
    my $json_result = undef;
    my $title       = undef;
    my $wurl        = undef;
    my $i           = 0;

    my @messages = (
"Hi! I found an #wikipedia entry for _TITLE_: _WURL_ \#europeana has a picture: _URL_",
"Oh! A picture of _TITLE_  at _YEAR_ from \#europeana: _URL_ Learn More at #wikipedia: _WURL_",
"_TITLE_: #wikipedia entry _WURL_  #europeana picture: _URL_ You are welcome!"
    );
    @messages = shuffle @messages;

    $self->log->debug("I'm gonna tweet about a random Wikipedia Page!");

    # set UserAgent per API Policy
    # http://www.mediawiki.org/wiki/API#Identifying_your_client
    $ua->agent( $self->user_agent );

    while (1) {
        $i++;

        $json_result =
          get( $self->wikipedia_base
              . "/w/api.php?action=query&list=random&rnnamespace=0&rnlimit=1&format=json"
          );
        $result_ref = decode_json($json_result);
        $self->log->debug(
            "Result: " . $result_ref->{query}->{random}->[0]->{title} );

        if ( $title = $result_ref->{query}->{random}->[0]->{title} ) {

            $result_ref = $self->getEuropeanaResults(
                Query => "\"" . $title . "\"",
                Field => 'title',
                Type  => 'IMAGE',
                Rows  => 10
            );

            if ( $result_ref->{Status} eq 'OK' ) {
                $self->log->info(
"Needed $i tries to find a Result for a random Wikipedia Page!"
                );

                # get shortened wikipedia URL
                $wurl =
                  get(  $self->url_shortener
                      . $self->wikipedia_base
                      . "/wiki/"
                      . uri_escape($title) );

                $messages[0] =~ s/_WURL_/$wurl/;

                $self->post2Twitter(
                    Result  => $result_ref,
                    Message => $messages[0]
                );

                return;
            }
            sleep( 1 + int( rand(4) ) );    # sleep max 5 seconds

        }

    }
}

=head2 writeGuardianNewsTweet()

posts a search result about a recent Guardian News Item

=cut

sub writeGuardianNewsTweet {
    my $self        = shift;
    my $request     = undef;
    my $result_ref  = undef;
    my $json_result = undef;
    my @results     = ();
    my @tags        = ();
    my $gurl        = undef;
    my $i           = 0;
    my $date        = undef;

    $date = POSIX::strftime( "%Y-%m-%d", localtime );

    my @messages = (
"Hi! The \#guardian has a news item about _TITLE_: _GURL_ \#europeana has a picture: _URL_",
"Oh! An article about _TITLE_  in the \#guardian: _GURL_  Here's the \#europeana picture: _URL_",
"_TITLE_: \#guardian article: _GURL_  \#europeana picture: _URL_ You are welcome!"
    );
    @messages = shuffle @messages;

    $self->log->debug("I'm gonna tweet about a Guardian News Item!");

    $ua->agent( $self->user_agent );

    while (1) {

        $request =
            $self->guardian_api_url
          . "?from-date="
          . $date
          . "&to-date="
          . $date
          . "&page-size=10&format=json&show-tags=keyword&api-key="
          . $self->guardian_api_key;

        $json_result = get($request);
        $result_ref  = decode_json($json_result);

        if (
            (
                defined($result_ref)
                && ( defined( $result_ref->{response}->{total} ) )
            )
            && ( $result_ref->{response}->{total} > 0 )
          )
        {

            $self->log->debug( $result_ref->{response}->{total} . " results" );

            @results = shuffle @{ $result_ref->{response}->{results} };

            # get keywords for Europeana Search
            @tags = shuffle @{ $results[0]->{tags} };

            foreach my $tag (@tags) {

                $i++;

                $result_ref = $self->getEuropeanaResults(
                    Query => "\"" . $tag->{webTitle} . "\"",
                    Field => 'title',
                    Type  => 'IMAGE',
                    Rows  => 10
                );

                if ( $result_ref->{Status} eq 'OK' ) {
                    $self->log->info(
"Needed $i tries to find a Result for a Guardian news tag!"
                    );

                    # get shortened wikipedia URL
                    $gurl = get( $self->url_shortener . $results[0]->{webUrl} );

                    $messages[0] =~ s/_GURL_/$gurl/;

                    $self->post2Twitter(
                        Result  => $result_ref,
                        Message => $messages[0]
                    );

                    return;
                }

            }

        }
        else {
            $self->log->error( "Problem with request: " . $request );

            $self->log->error("Activating Fallback-Cat!");
            $self->writeCatTweet();

        }

    }

}

=head2 writeCatTweet()

posts a cat picture

=cut

sub writeCatTweet {
    my $self       = shift;
    my $result_ref = undef;
    my @messages   = (
"So.. I heard you like cat pictures? \#europeana got you covered! _URL_",
"Everyone on the internet likes cat pictures, right? Go \#europeana! _URL_",
        "Look! Cats in \#europeana! _URL_",
    );
    @messages = shuffle @messages;

    $self->log->debug("I'm gonna tweet about cats!");

    $result_ref = $self->getEuropeanaResults(
        Query => "katzen",
        Field => 'title',
        Type  => 'IMAGE',
        Rows  => 25
    );
    if ( $result_ref->{Status} eq 'OK' ) {
        $self->post2Twitter(
            Result  => $result_ref,
            Message => $messages[0]
        );

        return;
    }
}

=head2 writeHammerTimeTweet()

"Stop! Hammertime!"

=cut

sub writeHammerTimeTweet {
    my $self       = shift;
    my $result_ref = undef;
    my @seeds      = @{ $self->{LocationSeeds} };
    my $message    = "Stop! Hammertime! _URL_";

    $self->log->debug("Oh.. It's Hammertime!");

    $result_ref = $self->getEuropeanaResults(
        Query => "hammer",
        Field => 'title',
        Type  => 'IMAGE',
        Rows  => 25
    );
    if ( $result_ref->{Status} eq 'OK' ) {
        $self->post2Twitter(
            Result  => $result_ref,
            Message => $message
        );

        return;
    }
}

=head2 writeUnicornTweet()

tweet about Unicorns

=cut

sub writeUnicornTweet {
    my $self       = shift;
    my $result_ref = undef;
    my @seeds      = @{ $self->{LocationSeeds} };
    my $message =
      "I've got a soft spot for unicorns.. Thanks \#europeana! _URL_";

    $self->log->debug("Einhornzeit!");

    $result_ref = $self->getEuropeanaResults(
        Query => "einhorn",
        Field => 'title',
        Type  => 'IMAGE',
        Rows  => 12
    );
    if ( $result_ref->{Status} eq 'OK' ) {
        $self->post2Twitter(
            Result  => $result_ref,
            Message => $message
        );

        return;
    }
}

=head2 writeMondayTweet()

posts a picture of some cute kittens

=cut

sub writeMondayTweet {
    my $self       = shift;
    my $result_ref = undef;
    my $message =
"I know it's Monday morning.. Here's a picture of some cute kittens to cheer you up! _URL_";

    $self->log->debug("I'm gonna tweet about Monday Mimimimi");

    $result_ref = $self->getEuropeanaResults(
        Query => "cute kittens",
        Field => 'title',
        Type  => 'IMAGE',
        Rows  => 5
    );
    if ( $result_ref->{Status} eq 'OK' ) {
        $self->post2Twitter(
            Result  => $result_ref,
            Message => $message
        );

        return;
    }
}

=head2 writeFollowFridayTweet()

posts a Follower suggestions

=cut

sub writeFollowFridayTweet {
    my $self       = shift;
    my $result_ref = undef;
    my @messages   = (
"It's \#FollowFriday! Why not follow the official Europeana account? \@EuropeanaEU \#ff",
"It's \#FollowFriday! Wanna learn more about the techie side of Europeana? Why not follow \@EuropeanaTech? \#ff",
"I'm not really interested in fashion, but maybe you? Follow \@EurFashion! \#ff",
"Wanna learn more about the cooperation between Wikipedia and Europeana? Follow \@wikieuropeana! \#ff"
    );

    @messages = shuffle @messages;

    $self->log->debug("I'm gonna tweet about \#FollowFriday");

    $self->post2Twitter(
        Result  => $result_ref,
        Message => $messages[0],
    );

    return;
}

__PACKAGE__->meta->make_immutable;

1;    # End of Twitter::EuropeanaBot

=head1 AUTHOR

Peter Mayr, C<< <at.peter.mayr at gmail.com> >>

=head1 BUGS

Please report any bugs at L<https://github.com/hatorikibble/twitter-europeanabot>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Twitter::EuropeanaBot


You can also look for information at:

=over 4

=item * GitHub

L<https://github.com/hatorikibble/twitter-europeanabot>

=back


=head1 ACKNOWLEDGEMENTS

Basic idea taken from L<https://twitter.com/DPLAbot>

=head1 LICENSE AND COPYRIGHT

Copyright 2013 Peter Mayr.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

## Please see file perltidy.ERR
