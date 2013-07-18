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

use File::Slurp;
use JSON;
use List::Util qw( shuffle);
use LWP::Simple;
use Net::Twitter;
use URI::Escape;

use Data::Dumper;

our $VERSION = '0.01';

use Moose;
with
  qw( MooseX::Getopt MooseX::Log::Log4perl MooseX::Daemonize MooseX::Runnable   );

use Moose::Util::TypeConstraints;

subtype 'SeedFile',
  as 'Str',
  where { -e $_ },
  message { "Cannot find Seedfile at $_" };

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
has 'url_shortener' => ( is => 'ro', isa => 'Str',      required => 1 );
has 'seed_file'     => ( is => 'ro', isa => 'SeedFile', required => 1 );
has 'sleep_time'    => ( is => 'ro', isa => 'Int',      default  => 2000 );

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
    return unless $self->is_daemon;

    $self->log->info("Daemon started..");

    @seeds = @{ $self->createSeed() };

    while (1) {
        foreach my $term (@seeds) {
            $self->log->debug("searching for $term");
            $result_ref = $self->getEuropeanaResult( TitleQuery => $term );
            if ( $result_ref->{Status} eq 'OK' ) {
                $self->post2Twitter( Result => $result_ref );
            }
            $self->log->debug( "I'm going to sleep for " . $self->sleep_time. "seconds" );
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

=head2 createSeed

reads the contents of C<$self->seed_file> 
and returns an array with search terms

=cut

sub createSeed {
    my $self  = shift;
    my @lines = ();
    my @tmp   = ();

    $self->log->debug( "Creating seeds from file: " . $self->seed_file );
    eval { @lines = read_file( $self->seed_file ); };
    if ($@) {
        $self->log->error(
            "Cannot read seed_file " . $self->seed_file . ": " . $@ );
        return \@lines;
    }
    else {
        @lines = shuffle @lines;

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
        return \@lines;
    }

} ## end sub createSeed

=head2 getEuropeanaResult(TitleQuery=>'Linz')

searches Europeana and returns the first matching Result

Parameters

=over 

=item  * TitleQuery

querystring for title search

=back

=cut

sub getEuropeanaResult {
    my ( $self, %p ) = @_;
    my $json_result  = undef;
    my $result_ref   = undef;
    my $query_string = undef;

    #build $query_string
    $query_string =
        $self->europeana_api_url
      . "?wskey="
      . $self->europeana_api_key
      . "&rows=1&qf=TYPE:IMAGE&query=title:"
      . uri_escape( $p{TitleQuery} );

    $self->log->debug( "QueryString is: " . $query_string );
    if ( $json_result = get $query_string) {
        $result_ref = decode_json($json_result);
        $self->log->debug( "Result: " . Dumper( $result_ref->{itemsCount} ) );
        if ( $result_ref->{itemsCount} == 1 ) {

            # custom enrichment
            $result_ref->{Status}     = "OK";
            $result_ref->{TitleQuery} = $p{TitleQuery};
            return $result_ref;
        }
        else {
            $result_ref->{Status}     = "NotOK";
            $result_ref->{TitleQuery} = $p{TitleQuery};
            return $result_ref;
        }

    }

}

=head2 post2Twitter(Result=>$result)

posts the result to the twitter account specified by C<$self->twitter_account>

Parameters

=over

=item  * Result

Europeana Search Result

=back

=cut

sub post2Twitter {
    my ( $self, %p ) = @_;
    my $nt_result = undef;
    my $short_url = undef;
    my $status    = undef;
    my $nt        = Net::Twitter->new(
        traits              => [qw/API::RESTv1_1/],
        consumer_key        => $self->twitter_consumer_key,
        consumer_secret     => $self->twitter_consumer_secret,
        access_token        => $self->twitter_access_token,
        access_token_secret => $self->twitter_access_token_secret,
    );
    my @messages = (
        "Hi! I found an image of _TITLE_ from _YEAR_ at \#europeana: _URL_",
        "Oh! _TITLE_ at _YEAR_ from \#europeana: _URL_",
        "Look! A \#europeana Image: _TITLE_ at _YEAR_ _URL_",
"Hi! Are you interested in an \#europeana image of _TITLE_ from _YEAR_? _URL_"
    );
    @messages = shuffle @messages;

    $short_url = get( $self->url_shortener . $p{Result}->{items}->[0]->{guid} );

    $status = $messages[0];
    $status =~ s/_TITLE_/$p{Result}->{TitleQuery}/;
    $status =~ s/_URL_/$short_url/;

    if ( defined( $p{Result}->{items}->[0]->{year}->[0] ) ) {
        $status =~ s/_YEAR_/$p{Result}->{items}->[0]->{year}->[0]/;

    }
    else {
        $status =~ s/(from|at) _YEAR_//;

    }

    $self->log->info(
        "Posting Status: " . $status . " (" . length($status) . ")" );

    if ( length($status) > 140 ) {
        $self->log->warn("Status is too long!");
    }
    else {

        eval { $nt_result = $nt->update($status); };
        if ( $@ ) {
            $self->logger->error( "Error posting to "
                  . $self->twitter_account . ": "
                  . $@
                  . "!" );

        }
    }

    # $self->log->debug( Dumper($nt_result) );

} ## end sub post2Twitter

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
