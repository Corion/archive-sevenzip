package Archive::SevenZip::API::ArchiveTar;
use strict;
use Archive::SevenZip;

use vars qw($VERSION);
$VERSION= '0.06';

=head1 NAME

Archive::SevenZip::API::ArchiveTar - Archive::Tar-compatibility API

=head1 SYNOPSIS

  my $ar = Archive::SevenZip->archiveTarApi(
      find => 1,
      archivename => $archivename,
      verbose => $verbose,
  );
  print "$_\n" for $ar->list_files;

This module implements just enough of the L<Archive::Tar>
API to make extracting work. Ideally
use this API to enable a script that uses Archive::Tar
to also read other archive files supported by 7z.

=cut

sub new {
    my( $class, %options )= @_;
    $options{ sevenZip } = Archive::SevenZip->new();
    bless \%options => $class;
};

sub sevenZip { $_[0]->{sevenZip} }

sub contains_file {
    my( $self, $name ) = @_;
    $self->sevenZip->memmberNamed( $name )
};

sub get_content {
    my( $self, $name ) = @_;
    $self->sevenZip->content( $name );
};

sub list_files {
    my ($self,$properties) = @_;
    croak "Listing properties is not (yet) implemented"
        if $properties;
    my @files = $self->sevenZip->list;
    map { $_->fileName } @files
}

sub extract_file {
    my ($self,$file,$target) = @_;
    $self->sevenZip->extractMember( $file => $target );
};


1;