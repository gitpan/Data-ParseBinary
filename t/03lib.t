#!/usr/bin/perl -w
use strict;
use warnings;
use FindBin;
use Data::Dumper;
use Data::ParseBinary;
#use Test::More tests => 141;
use Test::More qw(no_plan);
$| = 1;

my $mydir = $FindBin::Bin . "/";
 
my $bmp_parser = Data::ParseBinary->Library('Graphics-BMP');

Test_BMP_Format("bitmapx1.bmp", [map { [ split '', $_ ] } qw{11100 11110 01111 00111 00011 00001 00000}]);
Test_BMP_Format("bitmapx4.bmp", [map { [ split '\\.', $_ ] } qw{15.15.15.10.10 15.15.15.15.10 9.15.15.15.15 9.9.15.15.15 9.9.9.15.15 9.9.9.9.15 9.9.9.9.9}]);
Test_BMP_Format("bitmapx8.bmp", [map { [ split '\\.', $_ ] } qw{228.228.228.144.144 228.228.228.228.144 251.228.228.228.228 251.251.228.228.228 251.251.251.228.228 251.251.251.251.228 251.251.251.251.251}]);
my %dict = (1 => [192, 128, 128], 2 => [128, 64, 0], 3 => [0, 255, 255], 4 => [159, 162, 64]);
Test_BMP_Format("bitmapx24.bmp", [map { [ map $dict{$_}, split '\\.', $_ ] } qw{1.1.1.2.2 1.1.1.1.2 3.1.1.1.1 3.3.1.1.1 3.3.3.1.1 3.3.3.3.1 4.3.3.3.3}]);

my $emf_parser = Data::ParseBinary->Library('Graphics-EMF');
#test_parse_build($emf_parser, "emf1.emf");

my $png_parser = Data::ParseBinary->Library('Graphics-PNG');
test_parse_build($png_parser, "png1.png");
#test_parse_build($png_parser, "png2.png");

my $wmf_parser = Data::ParseBinary->Library('Graphics-WMF');
test_parse_build($wmf_parser, "wmf1.wmf");

my $exec_pe32 = Data::ParseBinary->Library('Executable-PE32');
test_parse_only($exec_pe32, "notepad.exe");
test_parse_only($exec_pe32, "sqlite3.dll");

my $exec_elf32 = Data::ParseBinary->Library('Executable-ELF32');
#$Data::ParseBinary::print_debug_info = 1;
test_parse_build($exec_elf32, "_ctypes_test.so");

my $data_cap = Data::ParseBinary->Library('Data-TermCapture');
test_parse_only($data_cap, "cap2.cap");


sub test_parse_build {
    my ($parser, $filename) = @_;
    my $data = test_parse_only($parser, $filename);
    ok( copmare_scalar_file($parser, $data, $filename), "Built $filename");
}

sub test_parse_only {
    my ($parser, $filename) = @_;
    open my $fh2, "<", $mydir . $filename or die "can not open $filename";
    binmode $fh2;
    my $data = $parser->parse(CreateStreamReader(File => $fh2));
    ok( 1, "Parsed $filename");
    return $data;
}

sub Test_BMP_Format {
    my ($filename, $expected_pixels) = @_; 
    open my $fh2, "<", $mydir . $filename or die "can not open $filename";
    binmode $fh2;
    my $data = $bmp_parser->parse(CreateStreamReader(File => $fh2));
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

