#!/usr/bin/perl

use strict;

BEGIN {
    $|  = 1;
    $^W = 1;
}
use Archive::SevenZip;
use FileHandle;
use File::Spec;

use Test::More tests => 2;
use t::common;

my $version = Archive::SevenZip->find_7z_executable();
if( ! $version ) {
    BAIL_OUT "7z binary not found (not installed?)";
};


use constant FILENAME => File::Spec->catfile(TESTDIR, 'testing.txt');

my $zip;
my @memberNames;

sub makeZip {
    my ($src, $dest, $pred) = @_;
    $zip = Archive::SevenZip->archiveZipApi();
    $zip->addTree($src, $dest,);
    @memberNames = $zip->memberNames();
}

sub makeZipAndLookFor {
    my ($src, $dest, $pred, $lookFor) = @_;
    makeZip($src, $dest, $pred);
    ok(@memberNames);
    ok((grep { $_ eq $lookFor } @memberNames) == 1)
      or print STDERR "Can't find $lookFor in ("
      . join(",", @memberNames) . ")\n";
}

my ($testFileVolume, $testFileDirs, $testFileName) = File::Spec->splitpath($0);

makeZipAndLookFor('.', '', sub { print "file $_\n"; -f && /\.t$/ },
    't/02_main.t');
# Not supported:
#makeZipAndLookFor('.',   'e/', sub { -f && /\.t$/ }, 'e/t/02_main.t');
#makeZipAndLookFor('./t', '',   sub { -f && /\.t$/ }, '02_main.t');
