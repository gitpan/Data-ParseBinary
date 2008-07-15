#!/usr/bin/perl -w
use strict;
use warnings;
use Data::Dumper;
use Data::ParseBinary;
use Test::More tests => 134;
#use Test::More qw(no_plan);
$| = 1;

ok( UBInt16("foo")->parse("\x01\x02") == 258, "Primitive: Parse: UBInt16");
ok( ULInt16("foo")->parse("\x01\x02") == 513, "Primitive: Parse: ULInt16");
ok( UBInt16("foo")->build(31337) eq 'zi', "Primitive: Build: UBInt16");
ok( SBInt16("foo")->build(-31337) eq "\x85\x97", , "Primitive: Build: SBInt16");
ok( SLInt16("foo")->build(-31337) eq "\x97\x85", , "Primitive: Build: SLInt16");

my $s = Struct("foo",
    UBInt8("a"),
    SLInt16("b")
);
my $hash = $s->parse("\x07\x00\x01");
ok( 2 == keys %$hash, "Struct: Parse: correct number of keys" );
ok( ( $hash->{a} == 7 ) && ( $hash->{b} == 256 ) , "Struct: Parse: correct elements");
ok( $s->build($hash) eq "\x07\x00\x01", "Struct: Build: Rebuild1");
$hash->{b} = 5000;
ok( $s->build($hash) eq "\x07\x88\x13", "Struct: Build: Rebuild2");

$s = Struct("foo",
    UBInt8("a"),
    UBInt16("b"),
    Struct("bar",
        UBInt8("a"),
        UBInt16("b"),
    )
);
$hash = $s->parse("ABBabb");
ok( 3 == keys %$hash, "Nested Struct: Parse: correct number of keys" );
ok( ( $hash->{a} == 65 ) && ( $hash->{b} == 16962 ) , "Nested Struct: Parse: correct elements1");
ok( $hash->{bar} && ref($hash->{bar}) && UNIVERSAL::isa($hash->{bar}, "HASH") , "Nested Struct: Parse: subhash exists");
ok( 2 == keys %{ $hash->{bar} }, "Nested Struct: Parse: correct number of keys" );
ok( ( $hash->{bar}->{a} == 97 ) && ( $hash->{bar}->{b} == 25186 ) , "Nested Struct: Parse: correct elements2");

$s = Sequence("foo",
    UBInt8("a"),
    UBInt16("b")
);
my $list = $s->parse("abb");
ok(( $list and ref $list and UNIVERSAL::isa($list, "ARRAY") ),  "Sequence: Parse: Returns array-ref");
ok( @$list == 2 ,  "Sequence: Parse: Returns 2 elements");
ok(( $list->[0] == 97 and $list->[1] == 25186 ),  "Sequence: Parse: correct data");
ok( $s->build([1,2]) eq "\x01\x00\x02", "Sequence: Build: correct");

$s = Sequence("foo",
    UBInt8("a"),
    UBInt16("b"),
    Sequence("bar",
        UBInt8("a"),
        UBInt16("b"),
    )
);
$list = $s->parse("ABBabb");
ok( @$list == 3 ,  "Nested Sequence: Parse: Returns 3 elements");
ok(( $list->[0] == 65 and $list->[1] == 16962 ),  "Nested Sequence: Parse: correct data 1");
$list = $list->[2];
ok(( $list and ref $list and UNIVERSAL::isa($list, "ARRAY") ),  "Nest Sequence: Parse: Returns array-ref");
ok(( $list->[0] == 97 and $list->[1] == 25186 ),  "Nested Sequence: Parse: correct data 2");

$s = Range(3, 7, UBInt8("foo"));
eval { $list = $s->parse("\x01\x02") };
ok( $@ , "Range: Parse: Die on too few elements");
$list = $s->parse("\x01\x02\x03");
ok(( $list and ref $list and UNIVERSAL::isa($list, "ARRAY") ),  "Range: Parse: Returns array-ref");
ok( $list->[2] == 3, "Range: Parse: correct data 1");
$list = $s->parse("\x01\x02\x03\x04\x05\x06\x07\x08\x09");
ok( @$list == 7 && $list->[6]==7, "Range: Parse: correct data 2");
eval { $s->build([1,2]) };
ok( $@ , "Range: Build: Die on too few elements");
eval { $s->build([1..8]) };
ok( $@ , "Range: Build: Die on too many elements");
ok( $s->build([1..7]) eq "\x01\x02\x03\x04\x05\x06\x07" , "Range: Build: correct");

$s = Array(4, UBInt8("foo"));
$list = $s->parse("\x01\x02\x03\x04");
ok( @$list == 4 && $list->[3] == 4, "StrictRepeater: Parse: correct elements1");
eval { $list = $s->parse("\x01\x02\x03") };
ok( $@ , "StrictRepeater: Parse: Die on too few elements");
$list = $s->parse("\x01\x02\x03\x04\x05");
ok( @$list == 4 && $list->[3] == 4, "StrictRepeater: Parse: correct elements2");
ok( $s->build([5,6,7,8]) eq "\x05\x06\x07\x08", "StrictRepeater: Build: normal build");
eval { $s->build([5,6,7,8,9]) };
ok( $@, "StrictRepeater: Build: dies on too many elements");

$s = GreedyRange(UBInt8("foo"));
$list = $s->parse("\x01");
ok(( $list and ref $list and UNIVERSAL::isa($list, "ARRAY") ),  "GreedyRange: Parse: Returns array-ref");
ok( @$list == 1 && $list->[0] == 1, "GreedyRange: Parse: correct elements1");
$list = $s->parse("\x01\x02\x03");
ok( @$list == 3 && $list->[2] == 3, "GreedyRange: Parse: correct elements2");
$list = $s->parse("\x01\x02\x03\x04\x05\x06");
ok( @$list == 6 && $list->[4] == 5, "GreedyRange: Parse: correct elements3");
eval { $list = $s->parse("") };
ok( $@ , "GreedyRange: Parse: Die on too few elements");
ok( $s->build([1,2]) eq "\x01\x02", "GreedyRange: Build: normal build");
eval{ $s->build([]) };
ok( $@, "GreedyRange: Build: dies on too few elements");

$s = OptionalGreedyRange(UBInt8("foo"));
$list = $s->parse("");
ok(( $list and ref $list and UNIVERSAL::isa($list, "ARRAY") and @$list == 0 ),  "OptionalGreedyRange: Parse: Returns array-ref");
$list = $s->parse("\x01\x02");
ok( @$list == 2 && $list->[1] == 2, "OptionalGreedyRange: Parse: correct elements2");
ok( $s->build([]) eq "", "OptionalGreedyRange: Build: empty build");
ok( $s->build([1,2]) eq "\x01\x02", "OptionalGreedyRange: Build: normal build");

$s = Array(5, Array(2, UBInt8("foo")));
$list = $s->parse("aabbccddee");
ok(( $list and ref $list and UNIVERSAL::isa($list, "ARRAY") and @$list == 5 ),  "Nested StrictRepeater: Parse: Returns array-ref");
foreach my $a (@$list) {
    ok(( $a and ref $a and UNIVERSAL::isa($a, "ARRAY") and @$a == 2 ),  "Nested StrictRepeater: Parse: Nested array-ref");
}
ok( $list->[2]->[1] == 99, "Nested StrictRepeater: Parse: Correct elements");

$s = Struct("foo",
    Padding(2),
    Flag("myflag"),
    Padding(5),
);
$list = $s->parse("\x00\x00\x01\x00\x00\x00\x00\x00");
ok(( $list and ref $list and UNIVERSAL::isa($list, "HASH") ),  "Struct with Padding, Flag: Parse: Returns hash-ref");
ok(( keys %$list == 1 and $list->{myflag} == 1 ), "Struct with Padding, Flag: Parse: correct elements");

$s = BitStruct("foo",
    Padding(2),
    Flag("myflag"),
    Padding(5),
);
$list = $s->parse("\x20");
ok(( $list and ref $list and UNIVERSAL::isa($list, "HASH") ),  "BitStruct with Padding, Flag: Parse: Returns hash-ref");
ok(( keys %$list == 1 and $list->{myflag} == 1 ), "BitStruct with Padding, Flag: Parse: correct elements");

$s = BitStruct("foo",
    BitField("a", 3),
    Flag("b"),
    Padding(3),
    Nibble("c"),
    BitField("d", 5),
);
$list = $s->parse("\xe1\x1f");
ok(( keys %$list == 4 and $list->{a} == 7 and $list->{b} == 0 ), "BitStruct: Parse: correct elements1");
ok(( $list->{c} == 8 and $list->{d} == 31 ), "BitStruct: Parse: correct elements2");

$s = BitStruct("foo",
    BitField("a", 3),
    Flag("b"),
    Padding(3),
    Nibble("c"),
    Struct("bar",
        Nibble("d"),
        Bit("e"),
    )
);
$list = $s->parse("\xe1\x1f");
ok(( keys %$list == 4 and UNIVERSAL::isa($list->{bar}, "HASH")), "Nested BitStruct: Parse: correct number of elements");
ok(( $list->{a} == 7 and $list->{b} == 0 and $list->{c} == 8 ), "Nested BitStruct: Parse: correct elements1");
ok(( $list->{bar}->{d} == 15 and $list->{bar}->{e} == 1 ), "Nested BitStruct: Parse: correct elements2");

$s = Enum(Byte("protocol"),
    TCP => 6,
    UDP => 17,
);
ok( $s->parse("\x06") eq 'TCP', "Enum: correct1");
ok( $s->parse("\x11") eq 'UDP', "Enum: correct1");
eval { $s->parse("\x12") };
ok( $@, "Enum: dies on undeclared value with default");
ok( $s->build("TCP") eq "\x06", "Enum: build 1");
ok( $s->build("UDP") eq "\x11", "Enum: build 2");

$s = Enum(Byte("protocol"),
    TCP => 6,
    UDP => 17,
    _default_ => "blah",
);
ok( $s->parse("\x11") eq 'UDP', "Enum with default: correct1");
ok( $s->parse("\x12") eq 'blah', "Enum with default: correct2");

$s = Enum(Byte("protocol"),
    TCP => 6,
    UDP => 17,
    _default_ => $DefaultPass,
);
ok( $s->parse("\x11") eq 'UDP', "Enum with pass: correct1");
ok( $s->parse("\x12") == 18, "Enum with pass: correct2");
ok( $s->parse("\xff") == 255, "Enum with pass: correct3");

ok( OneOf(UBInt8("foo"), [4,5,6,7])->parse("\x05") == 5, "OneOf: Parse: passing");
eval { OneOf(UBInt8("foo"), [4,5,6,7])->parse("\x08") };
ok( $@, "OneOf: Parse: blocking");
ok( OneOf(UBInt8("foo"), [4,5,6,7])->build(5) eq "\x05", "OneOf: Build: passing");
eval { OneOf(UBInt8("foo"), [4,5,6,7])->build(8) };
ok( $@, "OneOf: Build: blocking");

ok( NoneOf(UBInt8("foo"), [4,5,6,7])->parse("\x08") == 8, "NoneOf: Parse: passing");
eval { NoneOf(UBInt8("foo"), [4,5,6,7])->parse("\x06") };
ok( $@, "NoneOf: Parse: blocking");

$s = Struct("foo",
    Byte("length"),
    Field("data", sub { $_->ctx->{length} }),
);
$list = $s->parse("\x03ABC");
ok( $list->{data} eq 'ABC' && $list->{length} == 3, "MetaField: Parse: correct1");
$list = $s->parse("\x04ABCD");
ok( $list->{data} eq 'ABCD' && $list->{length} == 4, "MetaField: Parse: correct2");

ok( Field("foo", 3)->parse("ABCD") eq "ABC", "Field: Parse: route to StaticField");
ok( Field("foo", sub {return 3})->parse("ABCD") eq "ABC", "Field: Parse: route to MetaField");


$s = Struct("foo",
    Byte("length"),
    Array(sub { $_->ctx->{length}}, UBInt16("data")),
);
$list = $s->parse("\x03\x00\x01\x00\x02\x00\x03");
ok(( $list and ref $list and UNIVERSAL::isa($list, "HASH") and keys %$list == 2 ),  "MetaRepeater: Parse: Struct OK");
ok(( $list->{length} == 3 and $list->{data} and ref $list->{data}), "MetaRepeater: Parse: Data contains array ref");
ok(( UNIVERSAL::isa($list->{data}, "ARRAY") and @{ $list->{data} } == 3 ), "MetaRepeater: Parse: Array ref have 3 elements");
ok(( $list->{data}->[1] == 2 ), "MetaRepeater: Parse: correct value");

$s = RepeatUntil(sub {$_->obj eq "\x00"}, Field("data", 1));
$list = $s->parse("abcdef\x00this is another string");
my @expected = split '', "abcdef\x00";
ok( @$list == @expected, "RepeatUntil: Parse: correct number of elements");
for (0..$#$list) {
    ok( $expected[$_] eq $list->[$_], "RepeatUntil: Parse: correct element $_");
}

$s = Struct("foo",
    Enum(Byte("type"),
        INT1 => 1,
        INT2 => 2,
        INT4 => 3,
        STRING => 4,
    ),
    Switch("data", sub { $_->ctx->{type} },
        {
            "INT1" => UBInt8("spam"),
            "INT2" => UBInt16("spam"),
            "INT4" => UBInt32("spam"),
            "STRING" => String("spam", 6),
        }
    )
);
$list = $s->parse("\x01\x12");
ok(( keys %$list == 2 and $list->{type} eq 'INT1' and $list->{data} == 18 ), "Switch: Parse: Correct parse1");
$list = $s->parse("\x02\x12\x34");
ok(( keys %$list == 2 and $list->{type} eq 'INT2' and $list->{data} == 4660 ), "Switch: Parse: Correct parse2");
$list = $s->parse("\x03\x12\x34\x56\x78");
ok(( keys %$list == 2 and $list->{type} eq 'INT4' and $list->{data} == 305419896 ), "Switch: Parse: Correct parse3");
$list = $s->parse("\x04abcdef");
ok(( keys %$list == 2 and $list->{type} eq 'STRING' and $list->{data} eq 'abcdef' ), "Switch: Parse: Correct parse4");

$s = Struct("foo",
    Byte("type"),
    Switch("data", sub { $_->ctx->{type} },
        {
            1 => UBInt8("spam"),
            2 => UBInt16("spam"),
        },
        default => UBInt8("spam")
    )
);
$list = $s->parse("\x01\xff");
ok(( keys %$list == 2 and $list->{type} == 1 and $list->{data} == 255 ), "Switch with default: Parse: Correct parse1");
$list = $s->parse("\x02\xff\xff");
ok(( keys %$list == 2 and $list->{type} == 2 and $list->{data} == 65535 ), "Switch with default: Parse: Correct parse2");
$list = $s->parse("\x03\xff\xff");   # <-- uses the default construct
ok(( keys %$list == 2 and $list->{type} == 3 and $list->{data} == 255 ), "Switch with default: Parse: Correct parse3");

$s = Struct("foo",
    Byte("type"),
    Switch("data", sub { $_->ctx->{type} },
        {
            1 => UBInt8("spam"),
            2 => UBInt16("spam"),
        },
        default => $DefaultPass,
    )
);
$list = $s->parse("\x01\xff");
ok(( keys %$list == 2 and $list->{type} == 1 and $list->{data} == 255 ), "Switch with pass: Parse: Correct parse1");
$list = $s->parse("\x02\xff\xff");
ok(( keys %$list == 2 and $list->{type} == 2 and $list->{data} == 65535 ), "Switch with pass: Parse: Correct parse2");
$list = $s->parse("\x03\xff\xff");   # <-- uses the default construct
ok(( keys %$list == 2 and $list->{type} == 3 and exists $list->{data} and not defined $list->{data} ), "Switch with pass: Parse: Correct parse3");

$s = Struct("foo",
    Pointer(sub { 4 }, Byte("data1")),   # <-- data1 is at (absolute) position 4
    Pointer(sub { 7 }, Byte("data2")),   # <-- data2 is at (absolute) position 7
);

$list = $s->parse("\x00\x00\x00\x00\x01\x00\x00\x02");
ok(( $list->{data1} == 1 and $list->{data2} == 2 ), "Pointer: Parse: Correct"); 

$s = Struct("foo",
    Byte("padding_length"),
    Padding(sub { $_->ctx->{padding_length} } ),
    Byte("relative_offset"),
    Anchor("absolute_position"),
    Pointer(sub { $_->ctx->{absolute_position} + $_->ctx->{relative_offset} }, Byte("data")),
);

$list = $s->parse("\x05\x00\x00\x00\x00\x00\x03\x00\x00\x00\xff");
ok(( keys %$list == 4 and $list->{relative_offset} == 3 and $list->{absolute_position} == 7 ), "Pointer n Anchor: Parse: Correct1");
ok(( $list->{data} == 255 and $list->{padding_length} == 5 ), "Pointer n Anchor: Parse: Correct2");

ok(( String("foo", 5)->parse("hello") eq "hello"), "String: Parse: Simple");

$s = String("foo", 10, padchar => "X", paddir => "right");
ok(( $s->parse("helloXXXXX") eq 'hello' ), "Padded String: Parse: Simple");
ok(( $s->build("hello") eq 'helloXXXXX' ), "Padded String: Build: Simple");

$s = PascalString("foo");
ok(( $s->parse("\x05hello") eq 'hello'), "PascalString: Parse: Simple");
ok(( $s->build("hello world") eq "\x0bhello world"), "PascalString: Build: Simple");
$s = PascalString("foo", 'UBInt16');
ok(( $s->parse("\x00\x05hello") eq 'hello'), "PascalString: Parse: With cutsom length type");
ok(( $s->build("hello") eq "\x00\x05hello"), "PascalString: Build: With cutsom length type");

$s = CString("foo");
ok(( $s->parse("hello\x00") eq 'hello' ), "CString: Parse: Simple");
ok(( $s->build("hello") eq "hello\x00" ), "CString: Build: Simple");
$s = CString("foo", terminators => "XYZ");
ok(( $s->parse("helloX") eq 'hello' ), "CString: Parse: custom terminator1");
ok(( $s->parse("helloY") eq 'hello' ), "CString: Parse: custom terminator2");
ok(( $s->parse("helloZ") eq 'hello' ), "CString: Parse: custom terminator3");
ok(( $s->build("hello") eq "helloX" ), "CString: Build: custom terminator");


$s = Struct("foo",
    UBInt8("width"),
    UBInt8("height"),
    Value("total_pixels", sub { $_->ctx->{width} * $_->ctx->{height}}),
);
is_deeply( $s->parse("\x05\x05"), { width => 5, height => 5, total_pixels => 25 }, "Value: Parse: Simple");
$list = { width => 5, height => 5 };
ok(( $s->build($list) eq "\x05\x05"), "Value: Parse: Ignored");
is_deeply( $list, { width => 5, height => 5, total_pixels => 25 }, "Value: Parse: Added to hash");

$s = Struct("foo",
    Flag("has_options"),
    If(sub { $_->ctx->{has_options} },
        Bytes("options", 5)
    )
);
is_deeply( $s->parse("\x01hello"), {options => 'hello', has_options => 1 }, "If: Parse: True");
is_deeply( $s->parse("\x00hello"), {options => undef, has_options => 0 }, "If: Parse: False");

$s = Struct("foo",
    Flag("has_next"),
    If(sub { $_->ctx->{has_next} }, LazyBound("next", sub { $s })),
);
is_deeply( $s->parse("\x01\x01\x01\x00"), { has_next => 1, next => { has_next => 1, next => { has_next => 1, next => { has_next => 0, next => undef } } } }, "LazyBound: Parse: Correct");

$s = Struct("foo",
    Byte("a"),
    Peek(Byte("b")),
    Byte("c"),
);
is_deeply( $s->parse("\x01\x02"), {a=>1, b=>2, c=>2}, "Peek: Parse: Simple");

$s = Const(Bytes("magic", 6), "FOOBAR");
ok(($s->parse("FOOBAR") eq "FOOBAR"), "Const: Parse: OK");
eval { $s->parse("FOOBAX") };
ok( $@, "Const: Parse: Dies");

ok(( not defined Terminator()->parse("")), "Terminator: Parse: ok");
eval { Terminator->parse("x") };
ok( $@, "Terminator: Parse: dies");

$s = Struct("foo",
    Byte("a"),
    Alias("b", "a"),
);
is_deeply( $s->parse("\x03"), {a=>3, b=>3}, "Alias: Parse: Simple");

$s = Union("foo",
    UBInt32("a"),
    UBInt16("b")
);
is_deeply( $s->parse("\xaa\xbb\xcc\xdd"), { a => 2864434397, b => 43707 }, "Union: Parse: Simple");
ok(( $s->build( { a=> 2864434397 } ) eq "\xaa\xbb\xcc\xdd" ), "Union: Build: a");
ok(( $s->build( { b => 43707 } ) eq "\xaa\xbb\0\0" ), "Union: Build: b");


#print Dumper($list);
