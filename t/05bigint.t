#!/usr/bin/perl -w
use strict;
use warnings;
use Data::Dumper;
use Data::ParseBinary;
#use Test::More tests => 181;
use Test::More qw(no_plan);
$| = 1;

my ($s, $data, $string);

$s = SBInt64("BigOne");

$data = 1;
$string = "\0\0\0\0\0\0\0\1";
is_deeply($s->parse($string), $data, "SBInt64: Parse: one");
ok( $s->build($data) eq $string, "SBInt64: Build: one");
$data = -256;
$string = "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\0";
is_deeply($s->parse($string), $data, "SBInt64: Parse: minus 256");
ok( $s->build($data) eq $string, "SBInt64: Build: minus 256");

