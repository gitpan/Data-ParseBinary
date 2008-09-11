#!/usr/bin/perl -w
use strict;
use warnings;
use FindBin;
use Data::Dumper;
use Data::ParseBinary;
#use Test::More tests => 141;
use Test::More qw(no_plan);
$| = 1;

my ($data);
my $mydir = $FindBin::Bin . "/";
 
my $bmp_parser = Data::ParseBinary->Library('Graphics-BMP');

Test_BMP_Format("bitmapx1.bmp", [map { [ split '', $_ ] } qw{11100 11110 01111 00111 00011 00001 00000}]);
Test_BMP_Format("bitmapx4.bmp", [map { [ split '\\.', $_ ] } qw{15.15.15.10.10 15.15.15.15.10 9.15.15.15.15 9.9.15.15.15 9.9.9.15.15 9.9.9.9.15 9.9.9.9.9}]);
Test_BMP_Format("bitmapx8.bmp", [map { [ split '\\.', $_ ] } qw{228.228.228.144.144 228.228.228.228.144 251.228.228.228.228 251.251.228.228.228 251.251.251.228.228 251.251.251.251.228 251.251.251.251.251}]);
my %dict = (1 => [192, 128, 128], 2 => [128, 64, 0], 3 => [0, 255, 255], 4 => [159, 162, 64]);
Test_BMP_Format("bitmapx24.bmp", [map { [ map $dict{$_}, split '\\.', $_ ] } qw{1.1.1.2.2 1.1.1.1.2 3.1.1.1.1 3.3.1.1.1 3.3.3.1.1 3.3.3.3.1 4.3.3.3.3}]);

my $emf_parser = Data::ParseBinary->Library('Graphics-EMF');
#test_parse_only($emf_parser, "emf1.emf");

my $png_parser = Data::ParseBinary->Library('Graphics-PNG');
test_parse_only($png_parser, "png1.png");
#test_parse_only($png_parser, "png2.png");

my $wmf_parser = Data::ParseBinary->Library('Graphics-WMF');
test_parse_only($wmf_parser, "wmf1.wmf");

sub test_parse_only {
    my ($parser, $filename) = @_;
    open my $fh2, "<", $mydir . $filename or die "can not open $filename";
    binmode $fh2;
    $data = $parser->parse(CreateStreamReader(File => $fh2));
    ok( 1, "Parsed $filename");
}

sub Test_BMP_Format {
    my ($filename, $expected_pixels) = @_; 
    open my $fh2, "<", $mydir . $filename or die "can not open $filename";
    binmode $fh2;
    $data = $bmp_parser->parse(CreateStreamReader(File => $fh2));
    #print join(",", @$_), "\n" foreach (@{ $data->{pixels} });
    is_deeply($data->{pixels}, $expected_pixels, "$filename: Parse: OK");
    ok( copmare_scalar_file($bmp_parser, $data, $filename), "$filename: Build: OK");
}

sub copmare_scalar_file {
    my ($s, $data, $filename) = @_;
    my $content = $s->build($data);
    open my $cf, "<", $mydir . $filename or die "can not open $filename";
    binmode $cf;
    local $/ = undef;
    my $content2 = <$cf>;
    close $cf;
    return $content eq $content2;
}

