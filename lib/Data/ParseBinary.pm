package Data::ParseBinary;
use strict;
use warnings;
no warnings 'once';

our $VERSION = 0.01;

use Data::ParseBinary::Core;
use Data::ParseBinary::Adapters;
use Data::ParseBinary::Streams;
use Data::ParseBinary::Constructs;


sub UBInt16 { return Data::ParseBinary::Primitive->create($_[0], 2, "n") }
sub UBInt32 { return Data::ParseBinary::Primitive->create($_[0], 4, "N") }
sub ULInt16 { return Data::ParseBinary::Primitive->create($_[0], 2, "v") }
sub ULInt32 { return Data::ParseBinary::Primitive->create($_[0], 4, "V") }
sub UNInt32 { return Data::ParseBinary::Primitive->create($_[0], 4, "L") }
sub UNInt16 { return Data::ParseBinary::Primitive->create($_[0], 2, "S") }
sub UNInt8  { return Data::ParseBinary::Primitive->create($_[0], 1, "C") }
sub UNInt64 { return Data::ParseBinary::Primitive->create($_[0], 8, "Q") }
sub SNInt64 { return Data::ParseBinary::Primitive->create($_[0], 8, "q") }
sub SNInt32 { return Data::ParseBinary::Primitive->create($_[0], 4, "l") }
sub SNInt16 { return Data::ParseBinary::Primitive->create($_[0], 2, "s") }
sub SNInt8  { return Data::ParseBinary::Primitive->create($_[0], 1, "c") }
sub NFloat64{ return Data::ParseBinary::Primitive->create($_[0], 8, "d") }
sub NFloat32{ return Data::ParseBinary::Primitive->create($_[0], 4, "f") }
*SBInt8 = \&SNInt8;
*SLInt8 = \&SNInt8;
*Byte = \&UNInt8;
*UBInt8 = \&UNInt8;
*ULInt8 = \&UNInt8;

if ($^V ge v5.10.0) {
    *SBInt16 = sub { return Data::ParseBinary::Primitive->create($_[0], 2, "s>") };
    *SLInt16 = sub { return Data::ParseBinary::Primitive->create($_[0], 2, "s<") };
    *SBInt32 = sub { return Data::ParseBinary::Primitive->create($_[0], 2, "l>") };
    *SLInt32 = sub { return Data::ParseBinary::Primitive->create($_[0], 2, "l<") };
    *SBInt64 = sub { return Data::ParseBinary::Primitive->create($_[0], 8, "q>") };
    *SLInt64 = sub { return Data::ParseBinary::Primitive->create($_[0], 8, "q<") };
    *UBInt64 = sub { return Data::ParseBinary::Primitive->create($_[0], 8, "Q>") };
    *ULInt64 = sub { return Data::ParseBinary::Primitive->create($_[0], 8, "Q<") };
    *BFloat64= sub { return Data::ParseBinary::Primitive->create($_[0], 8, "d>") };
    *LFloat64= sub { return Data::ParseBinary::Primitive->create($_[0], 8, "d<") };
    *BFloat32= sub { return Data::ParseBinary::Primitive->create($_[0], 4, "f>") };
    *LFloat32= sub { return Data::ParseBinary::Primitive->create($_[0], 4, "f<") };
} else {
    my ($primitive_class, $reversed_class);
    if (pack('s', -31337) eq "\x85\x97") {
        $primitive_class = 'Data::ParseBinary::Primitive';
        $reversed_class  = 'Data::ParseBinary::ReveresedPrimitive';
    } else {
        $reversed_class  = 'Data::ParseBinary::Primitive';
        $primitive_class = 'Data::ParseBinary::ReveresedPrimitive';
    }
    *SBInt16 = sub { return $primitive_class->create($_[0], 2, "s") };
    *SLInt16 = sub { return $reversed_class->create($_[0], 2, "s") };
    *SBInt32 = sub { return $primitive_class->create($_[0], 2, "l") };
    *SLInt32 = sub { return $reversed_class->create($_[0], 2, "l") };
    *SBInt64 = sub { return $primitive_class->create($_[0], 8, "q") };
    *SLInt64 = sub { return $reversed_class->create($_[0], 8, "q") };
    *UBInt64 = sub { return $primitive_class->create($_[0], 8, "Q") };
    *ULInt64 = sub { return $reversed_class->create($_[0], 8, "Q") };
    *BFloat64= sub { return $primitive_class->create($_[0], 8, "d") };
    *LFloat64= sub { return $reversed_class->create($_[0], 8, "d") };
    *BFloat32= sub { return $primitive_class->create($_[0], 4, "f") };
    *LFloat32= sub { return $reversed_class->create($_[0], 4, "f") };
}

sub Struct  { return Data::ParseBinary::Struct->create(@_) }
sub Sequence{ return Data::ParseBinary::Sequence->create(@_) };
sub Array {
    my ($count, $sub) = @_;
    if ($count and ref($count) and UNIVERSAL::isa($count, "CODE")) {
        return Data::ParseBinary::MetaArray->create($count, $sub);
    } else {
        return Data::ParseBinary::MetaArray->create(sub {$count}, $sub);
    }
}

sub GreedyRange { return Data::ParseBinary::Range->create(1, undef, $_[0]); }
sub OptionalGreedyRange { return Data::ParseBinary::Range->create(0, undef, $_[0]); }
sub Range { return Data::ParseBinary::Range->create(@_) };
sub Padding   { return Data::ParseBinary::Padding->create($_[0]) }
sub Flag      { return Data::ParseBinary::BitField->create($_[0], 1) }
sub Bit       { return Data::ParseBinary::BitField->create($_[0], 1) }
sub Nibble    { return Data::ParseBinary::BitField->create($_[0], 4) }
sub Octet     { return Data::ParseBinary::BitField->create($_[0], 8) }
sub BitField  { return Data::ParseBinary::BitField->create(@_) }
sub BitStruct { return Data::ParseBinary::BitStruct->create(@_) }
sub Enum      { return Data::ParseBinary::Enum->create(@_) }
sub OneOf {
    my ($subcon, $list) = @_;
    my $code = sub {
        return grep $_ == $_[0], @$list;
    };
    return Data::ParseBinary::LamdaValidator->create($subcon, $code);
}
sub NoneOf {
    my ($subcon, $list) = @_;
    my $code = sub {
        my @res = grep $_ == $_[0], @$list;
        return @res == 0;
    };
    return Data::ParseBinary::LamdaValidator->create($subcon, $code);
}
sub Field {
    my ($name, $len) = @_;
    if ($len and ref($len) and UNIVERSAL::isa($len, "CODE")) {
        return Data::ParseBinary::MetaField->create($name, $len);
    } else {
        return Data::ParseBinary::StaticField->create($name, $len);
    }
}
*Bytes = \&Field;
sub RepeatUntil (&$) { return Data::ParseBinary::RepeatUntil->create(@_) }
sub StringAdapter {
    my ($subcon, %params) = @_;
    return Data::ParseBinary::StringAdapter->create($subcon, $params{encoding});
}
sub String {
    my ($name, $length, %params) = @_;
    if (not defined $params{padchar}) {
        return StringAdapter(Field($name, $length), encoding => $params{encoding});
    } else {
        return Data::ParseBinary::PaddedStringAdapter->create(Field($name, $length), length => $length, %params);
        #name, length, encoding = None, padchar = None, 
        #paddir = "right", trimdir = "right"
        #con = PaddedStringAdapter(con, 
        #    padchar = padchar, 
        #    paddir = paddir, 
        #    trimdir = trimdir
        #)
    }
}
sub LengthValueAdapter { return Data::ParseBinary::LengthValueAdapter->create(@_) }
sub PascalString {
    my ($name, $length_field_type, $encoding) = @_;
    $length_field_type ||= 'UBInt8';
    my $length_field;
    {
        no strict 'refs';
        $length_field = &$length_field_type('length');
    }
    return StringAdapter(
        LengthValueAdapter(
            Sequence($name,
                $length_field,
                Field("data", sub { $_->ctx->[0] }),
            )
        ),
        encoding => $encoding,
    );
    #name, length_field = UBInt8("length"), encoding = None
}

sub CString {
    my ($name, %params) = @_;
    my ($terminators, $encoding, $char_field) = @params{qw{terminators encoding char_field}}; 
    $terminators = "\x00" unless defined $terminators;
    $char_field ||= Field($name, 1);
    my @t_list = split '', $terminators;
    return Data::ParseBinary::CStringAdapter->create(
        Data::ParseBinary::JoinAdapter->create(
            RepeatUntil(sub { my $obj = $_->obj; grep($obj eq $_, @t_list) } ,$char_field)),
            $terminators, $encoding
        )
    #return Rename($name,
    #    CStringAdapter(
    #        RepeatUntil(sub { my $obj = $_->obj; grep($obj eq $_, @t_list) } ,$char_field),
    #        $terminators, $encoding
    #    )
    #)
}


sub Switch { return Data::ParseBinary::Switch->create(@_) }
sub Pointer { return Data::ParseBinary::Pointer->create(@_) }
sub Anchor { return Data::ParseBinary::Anchor->create(@_) }
sub LazyBound { return Data::ParseBinary::LazyBound->create(@_) }
sub Value { return Data::ParseBinary::Value->create(@_) }
sub Terminator { return Data::ParseBinary::Terminator->create() }

sub IfThenElse {
    my ($name, $predicate, $then_subcon, $else_subcon) = @_;
    return Switch($name, sub { &$predicate ? 1 : 0 },
        {
            1 => $then_subcon,
            0 => $else_subcon,
        }
    )
}

sub If {
    my ($predicate, $subcon, $elsevalue) = @_;
    return IfThenElse($subcon->_get_name(), 
        $predicate, 
        $subcon, 
        Value("elsevalue", sub { $elsevalue })
    )
}
sub Peek { Data::ParseBinary::Peek->create(@_) }
sub Const { Data::ParseBinary::ConstAdapter->create(@_) }
sub Alias {
    my ($newname, $oldname) = @_;
    return Value($newname, sub { $_->ctx->{$oldname}});
}

sub Union { Data::ParseBinary::Union->create(@_) }

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
    UBInt8
    ULInt8
    UNInt8
    SBInt8
    SNInt8
    SLInt8
    Byte
    UBInt16
    ULInt16
    UNInt16
    SBInt16
    SLInt16
    SNInt16
    UBInt32
    ULInt32
    UNInt32
    SNInt32
    SBInt32
    SLInt32
    NFloat32
    BFloat32
    LFloat32
    UNInt64
    UBInt64
    ULInt64
    SNInt64
    SBInt64
    SLInt64
    BFloat64
    LFloat64
    NFloat64

    Struct
    Sequence
    Range
    GreedyRange
    OptionalGreedyRange

    Padding

    Flag
    Bit
    Nibble
    Octet
    BitField
    BitStruct

    Enum
    $DefaultPass
    OneOf
    NoneOf
    Array
    RepeatUntil
    Field
    Bytes
    Switch
    Pointer
    Anchor

    String
    StringAdapter
    PascalString
    CString

    LazyBound
    Value
    IfThenElse
    If
    Peek
    Const
    Terminator
    Alias
    Union
);

1;

__END__

=head1 NAME

Data::ParseBinary - Yet Another parser for binary structures

=head1 SYNOPSIS

    $s = Struct("foo",
        UBInt8("a"),
        UBInt16("b"),
        Struct("bar",
            UBInt8("a"),
            UBInt16("b"),
        )
    );
    $data = $s->parse("ABBabb");
    # $data contains { a => 65, b => 16962, bar => { a == 97, b => 25186 } }

=head1 DESCRIPTION

This module is a Perl Port for PyConstructs http://construct.wikispaces.com/

Please note that this is a first experimental release. While the external interface is
more or less what I want it to be, the internals are still in flux.

This module enables writing declarations for simple and complex binary structures,
parsing binary to hash/array data structure, and building binary data from hash/array
data structure.

=head1 Reference Code

=head2 Primitives

First off, a list of primitive elements:

    UBInt8
    ULInt8
    UNInt8
    SBInt8
    SNInt8
    SLInt8
    Byte
    UBInt16
    ULInt16
    UNInt16
    SBInt16
    SLInt16
    SNInt16
    UBInt32
    ULInt32
    UNInt32
    SNInt32
    SBInt32
    SLInt32
    NFloat32
    BFloat32
    LFloat32
    UNInt64
    UBInt64
    ULInt64
    SNInt64
    SBInt64
    SLInt64
    BFloat64
    LFloat64
    NFloat64

S - Signed, U - Unsigned
N - Platform natural, L - Little endian, B - Big Endian
Samples:

    UBInt16("foo")->parse("\x01\x02") == 258
    ULInt16("foo")->parse("\x01\x02") == 513
    UBInt16("foo")->build(31337) eq 'zi'
    SBInt16("foo")->build(-31337) eq "\x85\x97"
    SLInt16("foo")->build(-31337) eq "\x97\x85"

=head2 Structs and Sequences

    $s = Struct("foo",
        UBInt8("a"),
        UBInt16("b"),
        Struct("bar",
            UBInt8("a"),
            UBInt16("b"),
        )
    );
    $data = $s->parse("ABBabb");
    # $data is { a => 65, b => 16962, bar => { a => 97, b => 25186 } }
    
    $s = Sequence("foo",
        UBInt8("a"),
        UBInt16("b"),
        Sequence("bar",
            UBInt8("a"),
            UBInt16("b"),
        )
    );
    $data = $s->parse("ABBabb");
    # $data is [ 65, 16962, [ 97, 25186 ] ]

=head2 Arrays and Ranges

    # This is an Array of four bytes
    $s = Array(4, UBInt8("foo"));
    $data = $s->parse("\x01\x02\x03\x04");
    # $data is [1, 2, 3, 4]
    
    # This is an array for 3 to 7 bytes
    $s = Range(3, 7, UBInt8("foo"));
    $data = $s->parse("\x01\x02\x03");
    $data = $s->parse("\x01\x02\x03\x04\x05\x06\x07\x08\x09");
    # in the last example, will take only 7 bytes from the stream
    
    # A range with at least one byte, unlimited
    $s = GreedyRange(UBInt8("foo"));
    
    # A range with zero to unlimited bytes
    $s = OptionalGreedyRange(UBInt8("foo"));

=head2 Padding and BitStructs

Padding remove bytes from the stream

    $s = Struct("foo",
        Padding(2),
        Flag("myflag"),
        Padding(5),
    );
    $data = $s->parse("\x00\x00\x01\x00\x00\x00\x00\x00");
    # $data is { myflag => 1 } 

Any bit field, when inserted inside a regular struct, will read one byte and
use only a few bits from the byte. for working with bits, BitStruct can be used.

    $s = BitStruct("foo",
        Padding(2),
        Flag("myflag"),
        Padding(5),
    );
    $data = $s->parse("\x20");
    # $data is { myflag => 1 } 

Padding in BitStruct remove bits from the stream, not bytes.

    $s = BitStruct("foo",
        BitField("a", 3), # three bit int
        Flag("b"),  # one bit
        Padding(3), # three bit padding
        Nibble("c"),  # four bit int
        BitField("d", 5), # five bit int
    );
    $data = $s->parse("\xe1\x1f");
    # $data is { a => 7, b => 0, c => 8, d => 31 }

there is also Octet that is eight bit int.

BitStruct must not be inside other BitStruct. use Struct for it.

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
    $data = $s->parse("\xe1\x1f");
    # $data is { a => 7, b => 0, bar => { c => 8, d => 31 }}

=head2 Adapters A Validators

Adapters are constructs that transform the data that they work on.
For creating an adapter, the class should inherent from the Data::ParseBinary::Adapter
class. For example:

    package IpAddressAdapter;
    our @ISA = qw{Data::ParseBinary::Adapter};
    sub _encode {
        my ($self, $tvalue) = @_;
        return pack "C4", split '\.', $tvalue;
    }
    sub _decode {
        my ($self, $value) = @_;
        return join '.', unpack "C4", $value;
    }

This adapter transforms dotted IP address ("1.2.3.4") for four bytes binary.
However, adapter need a underline data constructs. so for actually creating one
we should write:

    my $ipAdapter = IpAddressAdapter->create(Bytes("foo", 4));

(an adapter inherent its name from the underline data construct)
Or we can create an little function:

    sub IpAddressAdapterFunc {
        my $name = shift;
        IpAddressAdapter->create(Bytes($name, 4));
    }

And then:

    IpAddressAdapterFunc("foo")->parse("\x01\x02\x03\x04");

On additional note, it is possible to declare an "init" sub inside IpAddressAdapter,
that will receive any extra parameter that "create" recieved. 

One of the built-in Adatpers is Enum:

    $s = Enum(Byte("protocol"),
        TCP => 6,
        UDP => 17,
    );
    $s->parse("\x06") # return 'TCP'
    $s->parse("\x11") # return 'UDP'
    $s->build("TCP") # returns "\x06"

It is also possible to have a default:

    $s = Enum(Byte("protocol"),
        TCP => 6,
        UDP => 17,
        _default_ => "blah",
    );
    $s->parse("\x12") # returns 'blah'

And finally:

    $s = Enum(Byte("protocol"),
        TCP => 6,
        UDP => 17,
        _default_ => $DefaultPass,
    );
    $s->parse("\x12") # returns 18

$DefaultPass tells Enum that if it isn't familiar with the value, pass it alone.

We also have Validators. A Validator is an Adapter that instead of transforming data,
validate it. Examples:

    OneOf(UBInt8("foo"), [4,5,6,7])->parse("\x05") # return 5
    OneOf(UBInt8("foo"), [4,5,6,7])->parse("\x08") # dies.
    NoneOf(UBInt8("foo"), [4,5,6,7])->parse("\x08") # returns 8
    NoneOf(UBInt8("foo"), [4,5,6,7])->parse("\x05") # dies

=head2 Meta-Constructs

Life isn't always simple. If you only have a rigid structure with constance types,
then you can use other modules, that are far simplier. hack, use pack/unpack.

So if you have more complicate requirements, welcome to the meta-constructs.
The first on is the field. a Field is a chunk of bytes, with variable lenght:

    $s = Struct("foo",
        Byte("length"),
        Field("data", sub { $_->ctx->{length} }),
    );

(it can be also in constent lenght, by replacing the code section with, for example, 4)
So we have struct, that the first byte is the lenght of the field, and after that the field itself.
An example:

    $data = $s->parse("\x03ABC");
    # $data is {lenght => 3, data => "ABC"} 
    $data = $s->parse("\x04ABCD");
    # $data is {lenght => 4, data => "ABCD"} 

And so on.

In the meta-constructs, $_ is loaded with all the data that you need. $_->ctx is equal to $_->ctx(0),
that returns hash-ref containing all the data that the current struct parsed. In this example, it contain
only "length". Is you want to go another level up, just request $_->ctx(1).

Another meta-construct is the Array:

    $s = Struct("foo",
        Byte("length"),
        Array(sub { $_->ctx->{length}}, UBInt16("data")),
    );
    $data = $s->parse("\x03\x00\x01\x00\x02\x00\x03");
    # $data is {length => 3, data => [1, 2, 3]}

RepeatUntil gets for every round to inspect data on $_->obj:

    $s = RepeatUntil(sub {$_->obj eq "\x00"}, Field("data", 1));
    $data = $s->parse("abcdef\x00this is another string");
    # $data is [qw{a b c d e f}, "\0"]

OK. enough with the games. let's see some real branching.

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
    $data = $s->parse("\x01\x12");
    # $data is {type => "INT1", data => 18}
    $data = $s->parse("\x02\x12\x34");
    # $data is {type => "INT2", data => 4660}
    $data = $s->parse("\x04abcdef");
    # $data is {type => "STRING", data => 'abcdef'}

And so on. Switch also have a default option:

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

And can use $DefaultPass that make it to no-op.

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

Pointers are another animal of meta-struct. For example:

    $s = Struct("foo",
        Pointer(sub { 4 }, Byte("data1")),   # <-- data1 is at (absolute) position 4
        Pointer(sub { 7 }, Byte("data2")),   # <-- data2 is at (absolute) position 7
    );
    $data = $s->parse("\x00\x00\x00\x00\x01\x00\x00\x02");
    # $data is {data1=> 1 data2=>2 }

Literaly is says: jump to position 4, read byte, return to the beginning, jump to position 7,
read byte, return to the beginning.

Anchor can help a Pointer to find it's target:

    $s = Struct("foo",
        Byte("padding_length"),
        Padding(sub { $_->ctx->{padding_length} } ),
        Byte("relative_offset"),
        Anchor("absolute_position"),
        Pointer(sub { $_->ctx->{absolute_position} + $_->ctx->{relative_offset} }, Byte("data")),
    );
    $data = $s->parse("\x05\x00\x00\x00\x00\x00\x03\x00\x00\x00\xff");
    # $data is { absolute_position=> 7, relative_offset => 3, data => 255, padding_length => 5 }

Anchor saves the current location in the stream, enable the Pointer to jump to location
relative to it.

=head2 Strings

A string with constant length:

    String("foo", 5)->parse("hello")
    # returns "hello"

A Padded string with constant length:

    $s = String("foo", 10, padchar => "X", paddir => "right");
    $s->parse("helloXXXXX") # return "hello"
    $s->build("hello") # return 'helloXXXXX'

I think hat it speaks for itself. only that paddir can be noe of qw{right left center},
and there can be also trimdir that can be "right" or "left".

PascalString - String with a length marker in the beginning:

    $s = PascalString("foo");
    $s->build("hello world") # returns "\x0bhello world"

The marker can be of any kind:

    $s = PascalString("foo", 'UBInt16');
    $s->build("hello") # returns "\x00\x05hello"

And finally, CString:

    $s = CString("foo");
    $s->parse("hello\x00") # returns 'hello'

Can have many optional terminators:

    $s = CString("foo", terminators => "XYZ");
    $s->parse("helloY") # returns 'hello'

=head2 Various

Some verious constructs.

    $s = Struct("foo",
        UBInt8("width"),
        UBInt8("height"),
        Value("total_pixels", sub { $_->ctx->{width} * $_->ctx->{height}}),
    );

A calculated value - not in the stream.
    
    $s = Struct("foo",
        Flag("has_options"),
        If(sub { $_->ctx->{has_options} },
            Bytes("options", 5)
        )
    );
    
    $s = Struct("foo",
        Byte("a"),
        Peek(Byte("b")),
        Byte("c"),
    );

Peek is like Pointer for the current location. read the data, and then return to the location
before the data.

    $s = Const(Bytes("magic", 6), "FOOBAR");

Const verify that a certain value exists

    Terminator()->parse("")

verify that we reached the end of the stream

    $s = Struct("foo",
        Byte("a"),
        Alias("b", "a"),
    );

Copies "a" to "b".

    $s = Union("foo",
        UBInt32("a"),
        UBInt16("b")
    );
    $data = $s->parse("\xaa\xbb\xcc\xdd");
    # $data is { a => 2864434397, b => 43707 }

A Union. currently work only with primitives, and not on bit-stream.

=head2 LasyBound

This construct is estinental for recoursive constructs. However, I think that it makes
a circular reference, so be aware.

    $s = Struct("foo",
        Flag("has_next"),
        If(sub { $_->ctx->{has_next} }, LazyBound("next", sub { $s })),
    );
    $data = $s->parse("\x01\x01\x01\x00");
    # $data is:
    #    {
    #        has_next => 1,
    #        next => {
    #            has_next => 1,
    #            next => {
    #                has_next => 1,
    #                next => {
    #                    has_next => 0,
    #                    next => undef
    #                }
    #            }
    #        }
    #    }

=head1 TODO

The following elements were not implemented:

    OnDemand
    Optional
    Reconfig and a macro Rename
    Aligned and AlignedStruct
    Probe
    Embed
    Tunnel

Add encodings support for the Strings

Convert the original unit tests to Perl (and make them pass...)

A lot of fiddling with the internal

Streams: FileStream, SocketStream, SeekableWarpForSocketStream

Ability to give the parse function a stream/socket/filehandle instead of string

The documentation is just in its beginning

Union handle only primitives. need to be extended to other constructs, and bit-structs.

Padding/Stream/bitstream duality - need work

use is_deeply in the unit-tests

add the stream object to the parser object? can be usefull with Pointer.

use some nice exception system

=head1 Thread Safety

This is a pure perl module. there should be not problems.

=head1 BUGS

A lot - see the TODO section

This is a first release - your feedback will be appreciated.

=head1 SEE ALSO

Original PyConstructs homepage: http://construct.wikispaces.com/

=head1 AUTHOR

Fomberg Shmuel, E<lt>owner@semuel.co.ilE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Shmuel Fomberg.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
