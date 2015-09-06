package Archive::SevenZip::Entry;
use strict;
use Time::Piece; # for strptime
use File::Basename ();
use Path::Class ();

sub new {
    my( $class, %options) = @_;
    
    bless \%options => $class
}

sub archive {
    $_[0]->{_Container}
}

sub fileName {
    $_[0]->{Path}
}

# Class::Path API
sub basename {
    Path::Class::file( $_[0]->{Path} )->basename
}

sub components {
    my $cp = file( $_[0]->{Path} );
    $cp->components()
}

sub dir {
    # We need to return the appropriate class here
    # so that further calls to (like) dir->list
    # still work properly
    die "->dir Not implemented";
}

sub open {
    my( $self, $mode, $permissions )= @_;
    $self->archive->openMemberFH( membername => $self->fileName, binmode => $mode );
}
*fh = \&open; # Archive::Zip API

# Path::Class API
sub slurp {
    my( $self, %options )= @_;
    my $fh = $self->archive->openMemberFH( membername => $self->fileName, binmode => $options{ iomode } );
    local $/;
    <$fh>
}

# Archive::Zip API
#externalFileName()

# Archive::Zip API
#fileName()

# Archive::Zip API
#lastModFileDateTime()

# Archive::Zip API
#lastModTime()

1;