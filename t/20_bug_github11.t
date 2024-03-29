#!/usr/bin/perl

# Github 11: "CRC or size mismatch" when extracting member second time
# Test for correct functionality to prevent regression

use strict;
use warnings;

use Archive::SevenZip 'AZ_OK';
use File::Spec;
use File::Path;

use Test::More;
use lib '.';

BEGIN {
if( ! eval {
    require t::common;
    t::common->import;
    1
}) {
    plan skip_all => "Archive::Zip not installed, skipping compatibility tests";
    exit;
   }
   else {
       plan tests => 2;
   }
}

my $version = Archive::SevenZip->find_7z_executable();
if( ! $version ) {
    SKIP: { skip "7z binary not found (not installed?)", 2; };
    exit
};
diag "7-zip version $version";

# create test env
my $GH_ISSUE   = 'github11';
my $TEST_NAME  = "20_bug_$GH_ISSUE";
my $TEST_DIR   = File::Spec->catdir(TESTDIR, $TEST_NAME);
mkpath($TEST_DIR);

# test 1
my $DATA_DIR      = File::Spec->catfile('t', 'data');
my $GOOD_ZIP_FILE = File::Spec->catfile($DATA_DIR, "good_${GH_ISSUE}.zip");
my $GOOD_ZIP      = Archive::SevenZip->new($GOOD_ZIP_FILE);
my $MEMBER_FILE = 'FILE';
my $member      = $GOOD_ZIP->memberNamed($MEMBER_FILE);
my $OUT_FILE = File::Spec->catfile($TEST_DIR, "out");
# Extracting twice triggered the bug
$member->extractToFileNamed($OUT_FILE);
is($member->extractToFileNamed($OUT_FILE), AZ_OK, 'Testing known good zip');

# test 2
my $BAD_ZIP_FILE = File::Spec->catfile($DATA_DIR, "bad_${GH_ISSUE}.zip");
my $BAD_ZIP      = Archive::SevenZip->new($BAD_ZIP_FILE);
$member = $BAD_ZIP->memberNamed($MEMBER_FILE);
# Extracting twice triggered the bug
$member->extractToFileNamed($OUT_FILE);
is($member->extractToFileNamed($OUT_FILE), AZ_OK, 'Testing known bad zip');
