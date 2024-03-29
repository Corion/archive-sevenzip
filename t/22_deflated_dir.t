#!/usr/bin/perl

use strict;
use warnings;

use Archive::Zip qw( :ERROR_CODES );
use Archive::SevenZip;
use File::Spec;
use lib '.';
use t::common;

use Test::More tests => 4;

my $sevenzip = Archive::SevenZip->new();
my $zip = $sevenzip->archiveZipApi;
isa_ok( $sevenzip, 'Archive::SevenZip' );
is( $zip->read(File::Spec->catfile('t', 'data', 'jar.zip')), AZ_OK, 'Read file' );

my $ret = eval { $zip->writeToFileNamed(OUTPUTZIP) };

is($ret, AZ_OK, 'Wrote file');

my ($status, $zipout) = testZip();
# STDERR->print("status= $status, out=$zipout\n");
SKIP: {
    skip( "test zip doesn't work", 1 ) if $testZipDoesntWork;
    is( $status, 0, "output zip isn't corrupted" );
}
