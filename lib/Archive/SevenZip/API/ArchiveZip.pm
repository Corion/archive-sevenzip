package Archive::SevenZip::API::ArchiveZip;
use strict;
use Carp qw(croak);
use Encode qw( decode encode );
use File::Basename qw(dirname basename);
use File::Copy;
use Archive::SevenZip 'AZ_OK';

use vars qw($VERSION);
$VERSION= '0.01';

sub new {
    my( $class, %options )= @_;
    $options{ sevenZip } = Archive::SevenZip->new();
    bless \%options => $class;
};

sub sevenZip { $_[0]->{sevenZip} }

=head1 NAME

Archive::SevenZip::API::ArchiveZip - Archive::Zip compatibility API

=cut

sub writeToFileNamed {
    my( $self, $targetName )= @_;
    copy( $self->sevenZip->{archivename}, $targetName );
    return AZ_OK;
}

sub addFileOrDirectory {
    my($self, $name, $newName, $compressionLevel) = @_;
    $newName //= $name;
    $self->sevenZip->add(
        items => [ [$name, $newName] ],
        compression => $compressionLevel
    );
}

sub addString {
    my( $self, $content, $name, %options ) = @_;
    $self->sevenZip->add_scalar($name => $content);
    $self->memberNamed($name, %options);
}

sub addDirectory {
    # Create just a directory name
    my( $self, $name, $target, %options ) = @_;
    $target ||= $name;
    
    if( ref $name ) {
        croak "Hashref API not supported, sorry";
    };
    
    $self->sevenZip->add_directory($name, $target, %options);
    $self->memberNamed($target, %options);
}

sub members {
    my( $self ) = @_;
    $self->sevenZip->members;
}

=head2 C<< $ar->numberOfMembers >>

  my $count = $az->numberOfMembers();

=cut

sub numberOfMembers {
    my( $self, %options ) = @_;
    my @m = $self->members( %options );
    0+@m
}

=head2 C<< $az->memberNamed >>

  my $entry = $az->memberNamed('hello_world.txt');
  print $entry->fileName, "\n";

=cut

# Archive::Zip API
sub memberNamed {
    my( $self, $name, %options )= @_;
    $self->sevenZip->memberNamed($name, %options );
}

sub extractMember {
    my( $self, $name, $target, %options ) = @_;
    if( ref $name and $name->can('fileName')) {
        $name = $name->fileName;
    };
    $self->sevenZip->extractMember( $name, $target, %options );
}

__END__

=head1 CAUTION

This module tries to mimic the API of L<Archive::Zip>.

=head2 Differences between Archive::Zip and Archive::SevenZip

=head3 7-Zip does not guarantee the order of entries within an archive

The Archive::Zip test suite assumes that items added later to an
archive will appear later in the directory listing. 7-zip makes no
such guarantee.

=head1 REPOSITORY

The public repository of this module is 
L<http://github.com/Corion/archive-sevenzip>.

=head1 SUPPORT

The public support forum of this module is
L<https://perlmonks.org/>.

=head1 BUG TRACKER

Please report bugs in this module via the RT CPAN bug queue at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=Archive-SevenZip>
or via mail to L<archive-sevenzip-Bugs@rt.cpan.org>.

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2015-2016 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut