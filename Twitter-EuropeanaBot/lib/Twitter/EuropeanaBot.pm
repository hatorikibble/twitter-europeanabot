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

our $VERSION = '0.01';

use Moose;
  with qw( MooseX::Getopt MooseX::Log::Log4perl MooseX::Daemonize MooseX::Runnable   );

has 'debug' => (is => 'ro', isa=>'Bool', default=>0);
has 'dont_close_all_files' => (is => 'ro', isa=>'Bool', default=>1);

Log::Log4perl::init($Bin.'/logging.conf');

=head2 run

called by the perl script

=cut

sub run {
    my $self = shift;
    $self->start();
    exit(0);
}

after start => sub {
    my $self = shift;
    return unless $self->is_daemon;

    $self->log->info("Daemon started..");
    while (1) {

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

__PACKAGE__->meta->make_immutable;

1;    # End of Twitter::EuropeanaBot
