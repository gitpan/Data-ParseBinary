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
test_parse_build($exec_elf32, "_ctypes_test.so");

my $data_cap = Data::ParseBinary->Library('Data-TermCapture');
test_parse_build($data_cap, "cap2.cap");

my $fs_mbr = Data::ParseBinary->Library('FileSystem-MBR');
my $packed =
    "33C08ED0BC007CFB5007501FFCBE1B7CBF1B065057B9E501F3A4CBBDBE07B104386E00".
    "7C09751383C510E2F4CD188BF583C610497419382C74F6A0B507B4078BF0AC3C0074FC".
    "BB0700B40ECD10EBF2884E10E84600732AFE4610807E040B740B807E040C7405A0B607".
    "75D2804602068346080683560A00E821007305A0B607EBBC813EFE7D55AA740B807E10".
    "0074C8A0B707EBA98BFC1E578BF5CBBF05008A5600B408CD1372238AC1243F988ADE8A".
    "FC43F7E38BD186D6B106D2EE42F7E239560A77237205394608731CB80102BB007C8B4E".
    "028B5600CD1373514F744E32E48A5600CD13EBE48A560060BBAA55B441CD13723681FB".
    "55AA7530F6C101742B61606A006A00FF760AFF76086A0068007C6A016A10B4428BF4CD".
    "136161730E4F740B32E48A5600CD13EBD661F9C3496E76616C69642070617274697469".
    "6F6E207461626C65004572726F72206C6F6164696E67206F7065726174696E67207379".
    "7374656D004D697373696E67206F7065726174696E672073797374656D000000000000".
    "0000000000000000000000000000000000000000000000000000000000000000000000".
    "00000000000000000000000000000000002C4463B7BDB7BD00008001010007FEFFFF3F".
    "000000371671020000C1FF0FFEFFFF761671028A8FDF06000000000000000000000000".
    "000000000000000000000000000000000000000055AA";
my $string = pack "H*", $packed;
ok( $string eq $fs_mbr->build($fs_mbr->parse($string)), "FileSystem-MBR: re-build");

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

