package Path::Class::Archive;
use strict;
use Carp qw(croak);
use Encode qw( decode encode );
use File::Basename qw(dirname basename);

# Consider automatically trying $ENV{ProgramFiles} and $ENV{ProgramFiles(x86)}
# for finding 7-zip

use vars qw(%sevenzip_charsetname %class_defaults $VERSION);
$VERSION= '0.01';

%sevenzip_charsetname = (
    'UTF-8' => 'UTF-8',
    'Latin-1' => 'WIN',
    'ISO-8859-1' => 'WIN',
    '' => 'DOS', # dunno what the appropriate name would be
);

%class_defaults = (
    '7zip' => '7z',
    fs_encoding => 'UTF-8',
    default_options => [ "-y", "-bd" ],
);

sub find_7z_executable {
    my($class) = @_;
    my $old_default = $class_defaults{ '7zip' };
    my @search;
    if( $^O =~ /MSWin/i ) {
        @search = map { "$_\\7-Zip" } ($ENV{'ProgramFiles'}, $ENV{'ProgramFiles(x86)'});
    };
    my $found = $class->version;
    
    while( ! $found and @search) {
        my $dir = shift @search;
        $class_defaults{'7zip'} = "$dir/7z";
        $found = $class->version;
    };
    
    if( ! $found) {
        $class_defaults{ '7zip' } = $old_default;
    };
    
    return defined $found ? $found : ()
}

=head1 NAME

Path::Class::Archive - treat archives as directories

=cut

sub new {
    my( $class, %options);
    if( @_ == 2 ) {
        ($class, $options{ archivename }) = @_;
    } else {
        ($class, %options) = @_;
    };
    
    for( keys %class_defaults ) {
        $options{ $_ } //= $class_defaults{ $_ };
    };
    
    bless \%options => $class
}

sub version {
    my( $self_or_class, %options) = @_;
    for( keys %class_defaults ) {
        $options{ $_ } //= $class_defaults{ $_ };
    };
    my $self = ref $self_or_class ? $self_or_class : $self_or_class->new( %options );
    
    
    my $cmd = $self->get_command(
        command => '',
        archivename => undef,
    );
    my $fh = $self->run($cmd, binmode => ':raw');
    local $/ = "\n";
    my @output = <$fh>;
    if( @output > 5) {
        $output[1] =~ /^7-Zip\s+.*?(\d+\.\d+)\s+Copyright/
            or return undef;
        return $1;
    } else {
        return undef
    }
}

# Iterate over the entries in the archive
# Path::Class API
sub open {
    my( $self )= @_;
    my @contents = $self->list();
}

# Archive::Zip API
sub list {
    my( $self, %options )= @_;
    my $cmd = $self->get_command( command => "l", options => ["-slt"], %options );
    
    my $fh = $self->run($cmd, encoding => $options{ fs_encoding } );
    my @output = <$fh>;
    chomp @output;
    
    my %results = (
        header => [],
        archive => [],
    );
    
    # Get/skip header
    while( @output and $output[0] !~ /^--$/ ) {
        push @{ $results{ header }}, shift @output;
    };
    
    # Get/skip archive information
    while( @output and $output[0] !~ /^----------$/ ) {
        push @{ $results{ archive }}, shift @output;
    };
    
    if( $output[0] =~ /^----------$/ ) {
        shift @output;
    } else {
        warn "Unexpected line in 7zip output, hope that's OK: [$output[0]]";
    };

    my @members;

    # Split entries
    my %entry_info;
    while( @output ) {
        my $line = shift @output;
        if( $line =~ /^([\w ]+) =(?: (.*)|)$/ ) {
            $entry_info{ $1 } = $2;
        } elsif($line =~ /^\s*$/) {
            push @members, Path::Class::Archive::Entry7zip->new(
                %entry_info,
                _Container => $self,
            );
            %entry_info = ();
        } else {
            croak "Unknown file entry [$line]";
        };
    };
    
    return @members
}
*members = \&list;

sub openMemberFH {
    
    my( $self, %options );
    if( @_ == 2 ) {
        ($self,$options{ membername })= @_;
    } else {
        ($self,%options) = @_;
    };
    defined $options{ membername } or croak "Need member name to extract";
    
    my $cmd = $self->get_command( command => "e", options => ["-so"], members => [$options{membername}] );
    my $fh = $self->run($cmd, encoding => $options{ encoding }, binmode => $options{ binmode } );
    return $fh
}

# Archive::Zip API
sub extractMember {
    my( $self, $memberOrName, $extractedName ) = @_;
    $extractedName //= $memberOrName;
    
    my %options = %$self;
    
    my $target_dir = dirname $extractedName;
    my $target_name = basename $extractedName;
    my $cmd = $self->get_command(
        command     => "e",
        archivename => $options{ archivename }, 
        members     => [ $memberOrName ],
        options     => [ "-o$target_dir" ],
    );
    my $fh = $self->run($cmd, encoding => $options{ encoding } );
    
    while( <$fh>) {
        warn $_ if $self->{verbose};
    };
    if( basename $memberOrName ne $target_name ) {
        rename "$target_dir/" . basename($memberOrName) => $extractedName
            or croak "Couldn't move '$memberOrName' to '$extractedName': $?";
    };
    
};

sub add_quotes {
    map {
        defined $_ && /\s/ ? qq{"$_"} : $_
    } @_
};

sub get_command {
    my( $self, %options )= @_;
    $options{ members } ||= [];
    $options{ archivename } //= $self->{ archivename };
    $options{ fs_encoding } //= $self->{ fs_encoding } // $class_defaults{ fs_encoding };
    $options{ default_options } //= $self->{ default_options } // $class_defaults{ default_options };
    
    my $charset = $sevenzip_charsetname{ $options{ fs_encoding }}
        or croak "Unknown filesystem encoding '$options{ fs_encoding }'";
    for(@{ $options{ members }}) {
        $_ = encode $options{ fs_encoding }, $_;
    };

    # Now quote what needs to be quoted
    for( @{ $options{ options }}, @{ $options{ members }}, $options{ archivename }, "$self->{ '7zip' }") {
    };

    return [grep {defined $_}
        add_quotes($self->{ '7zip' }),
        @{ $options{ default_options }},
        $options{ command },
        "-scs$charset",
        add_quotes( @{ $options{ options }} ),
        add_quotes( $options{ archivename } ),
        add_quotes( @{ $options{ members }} ),
    ];
}

sub run {
    my( $self, $cmd, %options )= @_;
    
    my $mode = '-|';

    my $fh;
    if( $^O =~ /MSWin/i ) {
        #warn "Opening [@$cmd |]";
        my @cmd = @$cmd;
        #my @cmd = map { /\s/ ? qq{"$_"} : $_ } @$cmd;
        CORE::open( $fh, "@cmd 2>nul: |" )
            or croak "Couldn't launch [$mode @cmd]: $!/$?";
    } else {
        # We can't conveniently silence 7zip here as we want to keep
        # the list-open :-/
        CORE::open( $fh, $mode, @$cmd)
            or croak "Couldn't launch [$mode @$cmd]: $!/$?";
    };
    if( $options{ encoding }) {
        binmode $fh, ":encoding($options{ encoding })";
    } elsif( $options{ binmode } ) {
        binmode $fh, $options{ binmode };
    };
    
    if( $options{ skip }) {
        for( 1..$options{ skip }) {
            # Read that many lines
            local $/ = "\n";
            scalar <$fh>;
        };
    };
    
    $fh;
}

package Path::Class::Archive::Entry7zip;
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


package Path::Class::Archive::Handle;
use strict;

1;