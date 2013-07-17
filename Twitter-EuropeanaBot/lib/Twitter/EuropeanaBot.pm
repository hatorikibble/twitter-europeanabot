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


=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 function1

=cut

sub function1 {
}

=head2 function2

=cut

sub function2 {
}

=head1 AUTHOR

Peter Mayr, C<< <at.peter.mayr at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-twitter-europeanabot at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Twitter-EuropeanaBot>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Twitter::EuropeanaBot


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Twitter-EuropeanaBot>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Twitter-EuropeanaBot>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Twitter-EuropeanaBot>

=item * Search CPAN

L<http://search.cpan.org/dist/Twitter-EuropeanaBot/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Peter Mayr.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

use strict;
use warnings;
use namespace::autoclean;

use FindBin qw($Bin);
use Log::Log4perl qw( :levels);

use JSON;
use LWP::Simple;
use Net::Twitter;

use Data::Dumper;

our $VERSION = '0.01';

use Moose;
with
  qw( MooseX::Getopt MooseX::Log::Log4perl MooseX::Daemonize MooseX::Runnable   );

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
has 'sleep_time' => ( is => 'ro', isa => 'Int', default => 2000 );

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
    return unless $self->is_daemon;

    $self->log->info("Daemon started..");
    while (1) {

        $result_ref = $self->getEuropeanaResult( TitleQuery => 'Linz' );
        $self->post2Twitter( Result => $result_ref );
        $self->log->debug( "I'm going to sleep for " . $self->sleep_time );
        sleep( $self->sleep_time );
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
      . $p{TitleQuery};

    $self->log->debug( "QueryString is: " . $query_string );
    if ( $json_result = get $query_string) {
        $result_ref = decode_json($json_result);
        $self->log->debug( "Result: " . Dumper( $result_ref->{itemsCount} ) );
        if ( $result_ref->{itemsCount} == 1 ) {

            # custom enrichment
            $result_ref->{Status} = "OK";
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
    my $status = undef;
    my $nt        = Net::Twitter->new(
        traits              => [qw/API::RESTv1_1/],
        consumer_key        => $self->twitter_consumer_key . "XXXX",
        consumer_secret     => $self->twitter_consumer_secret,
        access_token        => $self->twitter_access_token,
        access_token_secret => $self->twitter_access_token_secret,
    );

    $status = "Hi! Are you interested in an image of ".$p{Result}->{TitleQuery}." from ".$p{Result}->{items}->[0]->{year}->[0]."? Discover Europeana! ".$p{Result}->{items}->[0]->{guid};
    
    
    $self->log->info("Posting Status: ".$status." (".length($status).")");
    
    
    # eval { $nt_result = $nt->update('Hello, world!'); };
    # if ( defined($@)) {
    #     $self->logger->error("Error posting to ".$self->twitter_account.": ".$@."!");
        
    # }

    # $self->log->debug( Dumper($nt_result) );

}

__PACKAGE__->meta->make_immutable;

1;    # End of Twitter::EuropeanaBot
