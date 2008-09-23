package Data::ParseBinary;
use strict;
use warnings;
no warnings 'once';

our $VERSION = 0.07;

use Data::ParseBinary::Core;
use Data::ParseBinary::Adapters;
use Data::ParseBinary::Streams;
use Data::ParseBinary::Stream::String;
use Data::ParseBinary::Stream::Wrapper;
use Data::ParseBinary::Stream::Bit;
use Data::ParseBinary::Stream::StringBuffer;
use Data::ParseBinary::Stream::File;
use Data::ParseBinary::Constructs;


our $DefaultPass = Data::ParseBinary::NullConstruct->create();
$Data::ParseBinary::BaseConstruct::DefaultPass = $DefaultPass;
our $print_debug_info = undef;


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
sub RoughUnion { Data::ParseBinary::RoughUnion->create(@_) }

*CreateStreamReader = \&Data::ParseBinary::Stream::Reader::CreateStreamReader;
*CreateStreamWriter = \&Data::ParseBinary::Stream::Writer::CreateStreamWriter;
sub ExtractingAdapter { Data::ParseBinary::ExtractingAdapter->create(@_) };

sub Aligned {
    my ($subcon, $modulus) = @_;
    $modulus ||= 4;
    die "Aligned should be more then 2" if $modulus < 2;
    my $sub_name = $subcon->_get_name();
    my $s = ExtractingAdapter(
        Struct($sub_name,
               Anchor("Aligned_before"),
               $subcon,
               Anchor("Aligned_after"),
               Padding(sub { ($modulus - (($_->ctx->{Aligned_after} - $_->ctx->{Aligned_before}) % $modulus)) % $modulus })
              ),
        $sub_name);
    return $s;
}

sub Restream { Data::ParseBinary::Restream->create(@_) }
sub Bitwise {
    my ($subcon) = @_;
    return Restream($subcon, "Bit", "Bit");
}

my %library_types = (
    'Graphics-BMP' => "Data::ParseBinary::lib::GraphicsBMP",
    'Graphics-EMF' => "Data::ParseBinary::lib::GraphicsEMF",
    'Graphics-PNG' => "Data::ParseBinary::lib::GraphicsPNG",
    'Graphics-WMF' => "Data::ParseBinary::lib::GraphicsWMF",
    'Executable-PE32' => "Data::ParseBinary::lib::ExecPE32",
    'Executable-ELF32' => "Data::ParseBinary::lib::ExecELF32",
    'Data-TermCapture' => "Data::ParseBinary::lib::DataCap",
    'FileSystem-MBR' => "Data::ParseBinary::lib::FileSystemMbr",
);

sub Library {
    my $type = pop @_;
    die "Parse Library: Type not recognized" unless exists $library_types{$type};
    my $type_name = $library_types{$type};
    return $type_name if ref $type_name; # already loaded
    eval qq{ require $type_name; };
    die $@ if $@;
    no strict 'refs';
    my $type_ref = ${$type_name . '::Parser'};
    $library_types{$type} = $type_ref;
    return $type_ref;
}

sub Magic {
    my ($data) = @_;
    return Const(Field(undef, length($data)), $data);
}

sub Select { Data::ParseBinary::Select->create(@_) }

sub Optional {
    my $subcon = shift;
    return Select($subcon, $DefaultPass);
}

sub FlagsEnum { Data::ParseBinary::FlagsEnum->create(@_) }

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
    RoughUnion
    
    CreateStreamReader
    CreateStreamWriter
    
    Aligned
    ExtractingAdapter
    Restream
    Bitwise
    Magic
    
    Optional
    Select
    FlagsEnum
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

BitStruct can be inside other BitStruct. Inside BitStruct, Struct and BitStruct are equivalents.

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
    # $data is { a => 7, b => 0, c => 8, bar => { d => 15, e => 1 } }

=head2 Adapters And Validators

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

(An adapter inherits its name from the underlying data construct)

Or we can create a little function:

    sub IpAddressAdapterFunc {
        my $name = shift;
        IpAddressAdapter->create(Bytes($name, 4));
    }

And then:

    IpAddressAdapterFunc("foo")->parse("\x01\x02\x03\x04");

On additional note, it is possible to declare an "init" sub inside IpAddressAdapter,
that will receive any extra parameter that "create" recieved. 

One of the built-in Adapters is Enum:

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

If the field represent a set of flags, then the library provide a construct just for that:

    $s = FlagsEnum(ULInt16("characteristics"),
        RELOCS_STRIPPED => 0x0001,
        EXECUTABLE_IMAGE => 0x0002,
        LINE_NUMS_STRIPPED => 0x0004,
        REMOVABLE_RUN_FROM_SWAP => 0x0400,
        BIG_ENDIAN_MACHINE => 0x8000,
    );
    $data = $s->parse("\2\4");
    # $data is { EXECUTABLE_IMAGE => 1, REMOVABLE_RUN_FROM_SWAP => 1 };

Of course, this is equvalent to creating a BitStruct, and specifing Flag-s in the
correct positions, and so on. but this is an easier way.

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
The first on is the field. a Field is a chunk of bytes, with variable length:

    $s = Struct("foo",
        Byte("length"),
        Field("data", sub { $_->ctx->{length} }),
    );

(it can be also in constent length, by replacing the code section with, for example, 4)
So we have struct, that the first byte is the length of the field, and after that the field itself.
An example:

    $data = $s->parse("\x03ABC");
    # $data is {length => 3, data => "ABC"} 
    $data = $s->parse("\x04ABCD");
    # $data is {length => 4, data => "ABCD"} 

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

Optional construct may or may not be in the stream. Of course, it need a seekable stream.
The optional section usually have a Const in them, that indicates is this section
exists. 

    my $wmf_file = Struct("wmf_file",
        Optional(
            Struct("placeable_header",
                Const(ULInt32("key"), 0x9AC6CDD7),
                ULInt16("handle"),),
            ),
        ),
        ULInt16("version"),
        ULInt32("size"), # file size is in words
    );

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

A Union. currently work only with constant-size constructs, (like primitives, Struct and such)
but not on bit-stream.

    $s = Struct("records",
        ULInt32("record_size"),
        RoughUnion("params",
            Field("raw", sub { $_->ctx(1)->{record_size} - 8 }),
            Array(sub { int(($_->ctx(1)->{record_size} - 8) / 4) }, ULInt32("params")),
        ),
    );

RoughUnion is a type of Union, that doesn't check the size of it's sub-constructs.
it is used when we don't know before-hand the size of the sub-constructs, and the size
of the union as a whole. In the above example, we assume that if the union target is
the array of integers, then it probably record_size % 4 = 0.

If it's not, and we build this construct from the array, then we will be a few bytes
short. 

    $s = Struct("bmp",
        ULInt32("width"),
        ULInt32("height"),
        Array(
            sub { $_->ctx->{height} },
            Aligned(
                Array(
                    sub { $_->ctx(2)->{width} },
                    Byte("index")
                ),
            4),
        ),
    );

Aligned make sure that the contained construct's size if dividable by $modulo. the
syntex is:

    Aligned($subcon, $modulo);

In the above example, we have an excert from the BMP parser. each pixel is a byte.
There is an array of lines (height) that each line is an array of pixels. each line
is aligned to a four bytes boundary. 

The modulo can be any number. 2, 4, 8, 7, 23. 

    Magic("\x89PNG\r\n\x1a\n")

A constant string that is written / read and verified to / from the stream.
For example, every PNG file starts with eight pre-defined bytes. this construct
handle them, transparant to the calling program.

=head2 LasyBound

This construct is estinental for recoursive constructs.

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

=head1 Streams

Until now, everything worked in single-action. build built one construct, and parse
parsed one construct from one string. But suppose the string have more then one
construct in it? Suppose we want to write two constructs into one string? (and
if these constructs are in bit-mode, we can't create and just join them)

So, anyway, we have streams. A stream is an object that let a construct read and
parse bytes from, or build and write bytes to.

Please note, that some constructs can only work on seekable streams.

=head2 String

is seekable, not bit-stream

This is the most basic stream.

    $data = $s->parse("aabb");
    # is equivalent to:
    $stream = CreateStreamReader("aabb");
    $data = $s->parse($stream);
    # also equivalent to:
    $stream = CreateStreamReader(String => "aabb");
    $data = $s->parse($stream);

Being that String is the default stream type, it is not needed to specify it.
So, if there is a string contains two or more structs, that the following code is possible:

    $stream = CreateStreamReader(String => $my_string);
    $data1 = $s1->parse($stream);
    $data2 = $s2->parse($stream);

The other way is equally possible:

    $stream = CreateStreamWriter(String => undef);
    $s1->build($data1);
    $s2->build($data2);
    $my_string = $stream->Flush();

The Flush command in Writer Stream says: finish doing whatever you do, and return
your internal object. For string writer it is simply return the string that it built.
Wrapping streams (like Bit, StringBuffer) finish whatever they are doing, flush the
data to the internal stream, and call Flush on that internal stream.

The special case here is Wrap, that does not call Flush on the internal stream.
usefull for some configurations.
a Flush operation happens in the end of every build operation automatically, and
when a stream being destroyed. 

In creation, the following lines are equvalent:

    $stream = CreateStreamWriter(undef);
    $stream = CreateStreamWriter('');
    $stream = CreateStreamWriter(String => undef);
    $stream = CreateStreamWriter(String => '');

Of course, it is possible to create String Stream with inital string to append to:

    $stream = CreateStreamWriter(String => "aabb");

And any sequencal build operation will append to the "aabb" string.

=head2 StringRef

is seekable, not bit-stream

Mainly for cases when the string is to big to play around with. Writer:

    my $string = '';
    $stream = CreateStreamWriter(StringRef => \$string);
    ... do build operations ...
    # and now the data in $string.
    # or refer to: ${ $stream->Flush() }

Because Flush returns what's inside the stream - in this case a reference to a string.
For Reader:

    my $string = 'MBs of data...';
    $stream = CreateStreamReader(StringRef => \$string);
    ... parse operations ...

=head2 Bit

not seekable, is bit-stream

While every stream support bit-fields, when requesting 2 bits in non-bit-streams
you get these two bits, but a whole byte is consumed from the stream. In bit stream,
only two bits are consumed.

When you use BitStruct construct, it actually wraps the current stream with a bit stream.
If the stream is already bit-stream, it continues as usual.

What does it all have to do with you? great question. Support you have a string containing
a few bit structs, and each struct is aligned to a byte border. Then you can use
the example under the BitStruct section.

However, if the bit structs are not aligned, but compressed one against the other, then
you should use:

    $s = BitStruct("foo",
        Padding(1),
        Flag("myflag"),
        Padding(3),
    );
    $inner = "\x42\0";
    $stream1 = CreateStreamReader(Bit => String => $inner);
    $data1 = $s->parse($stream1);
    # data1 is { myflag => 1 }
    $data2 = $s->parse($stream1);
    # data2 is { myflag => 1 }
    $data3 = $s->parse($stream1);
    # data3 is { myflag => 0 }
    
Note that the Padding constructs detects that it work on bit stream, and pad in bits
instead of bytes.

On Flush the bit stream write the reminding bits (up to a byte border) as 0,
write the last byte to the contained stream, and call Flush on the said contained stream.
so, if we use the $s from the previous code section:

    $stream1 = CreateStreamWriter(Bit => String => undef);
    $s->build({ myflag => 1 }, $stream1);
    $s->build({ myflag => 1 }, $stream1);
    $s->build({ myflag => 0 }, $stream1);
    my $result = $stream1->Flush();
    # $result eq "\x40\x40\0"

In this case each build operation did Flush on the bit stream, closing the last
(and only) byte. so we get three bytes, each contain one record. But if we want
that our constructs will be compressed each against the other, then we need
to protect the bit stream from the Flush command:

    $stream1 = CreateStreamWriter(Wrap => Bit => String => undef);
    $s->build($data1, $stream1);
    $s->build($data1, $stream1);
    $s->build($data2, $stream1);
    my $result = $stream1->Flush()->Flush();
    # $result eq "\x42\0";

Ohh. Two Flushs. one for the Wrap, one for the Bit and the String.
However, as you can see, the structs are packed together. The Wrap stream protects
the Bit stream from the Flush command in the end of every build.

=head2 StringBuffer

is seekable, not bit-stream

Suppose that you have some non-seekable stream. like socket. and suppose that your
struct do use construct that need seekable stream. What can you do?

Enter StringBuffer. It reads from the warped stream exactly the number of bytes
that the struct needs, giving the struct the option to seek inside the read section.
and if the struct seeks ahead - it will just read enough bytes to seek to this place.

In writer stream, the StringBuffer will pospone writing the data to the actual stream,
until the Flush command.

This warper stream is usefull only when the struct seek inside it's borders, and
not sporadically reads data from 30 bytes ahead / back.

    # suppose we have unseekable reader stream names $s_stream
    # (for example, TCP connection)
    $stream1 = CreateStreamReader(StringBuffer => $s_stream);
    # $s is some struct that uses seek. (using Peek, for example)
    $data = $s->parse($stream1);
    # the data were read, you can either drop $stream1 or continue use
    # it for future parses.
    
    # now suppose we have a unseekable writer strea name $w_stream
    $stream1 = CreateStreamWriter(StringBuffer => $w_stream);
    # $s is some struct that uses seek. (using Peek, for example)
    $s->build($data1, $stream1);
    # data is written into $stream1, flushed to $w_stream, and sent.

Note that in StringBuffer, the Flush operation writes the data to the underlining
stream, and then Flushes that stream.

=head2 Wrap

A simple wraping stream, whose only function is to protect the contained stream
from Flush commands. Usable only for writer streams, and can be used to:

1. Protect a Bit stream, so it will compress multiple structs without byte alignment
(see the Bit stream documentation for example)

2. Protect a StringBuffer, so it will aggregate some structs before you will
Flush them all as one to the socket/file/whatever.

=head2 File

is seekable, not bit-stream

Reads from / Writes to a file. it is your responsebility to open the file and binmode it.

    open my $fh, "<", "bin_data.xdf" or die "oh sh...";
    binmode $fh;
    $stream1 = CreateStreamReader(File => $fh);

=head1 Format Library

The Data::ParseBinary arrive with ever-expanding set of pre-defined parser for popular formats.
And if you have a file-format, then this is how it's done:

    my $bmp_parser = Data::ParseBinary->Library('Graphics-BMP');
    open my $fh2, "<", $filename or die "can not open $filename";
    binmode $fh2;
    $data = $bmp_parser->parse(CreateStreamReader(File => $fh2));

And $data will contain the parsed file. In the same way, it is possible to build a BMP file.

The following explanations just highlight various issues with the various libraries.

=head2 Graphics: BMP

    my $bmp_parser = Data::ParseBinary->Library('Graphics-BMP');

Can parse / build any BMP file, (1, 4, 8 or 24 bit) as long as RLE is not used.

=head2 Graphics: EMF

    my $emf_parser = Data::ParseBinary->Library('Graphics-EMF');

This parser just do not work on my example file. Have to take a look on it.

=head2 Graphics: PNG

    my $png_parser = Data::ParseBinary->Library('Graphics-PNG');

Parses the binay PNG format, however it does not decompress the compressed data.
Also, it does not compute / verify the CRC values. 
these actions are left to other layer in the program.

=head2 Graphics: WMF

    my $wmf_parser = Data::ParseBinary->Library('Graphics-WMF');

No issues known.

=head2 Executable: PE32

    my $exec_pe32 = Data::ParseBinary->Library('Executable-PE32');

Can parse a Windows (and DOS?) EXE and DLL files. However, when building it back,
there are some minor differences from the original file, and Windows declare that
it's not a valid Win32 application.

=head2 Executable: ELF32

    my $exec_elf32 = Data::ParseBinary->Library('Executable-ELF32');

Can parse and re-build UNIX "so" files. 

=head2 Data: Term Capture

    my $data_cap = Data::ParseBinary->Library('Data-TermCapture');

Parsing "tcpdump capture file", whatever it is. Please note that this parser
have a lot of white space. (paddings) So when I rebuild the file, the padded
area is zeroed, and the re-created file does not match the original file.

I don't know if the recreated file is valid. 

=head2 File System: MBR

    my $fs_mbr = Data::ParseBinary->Library('FileSystem-MBR');

Can parse the binary structure of the MBR. (that is the structure that tells your
computer what partitions exists on the drive) Getting the data from there is your problem.

=head1 Debugging

=head2 $print_debug_info

Setting:

    $Data::ParseBinary::print_debug_info = 1;

Will trigger a print every time the parsing process enter or exit a construct.
So if a parsing dies, you can follow where it did.

=head1 TODO

The following elements were not implemented:

    OnDemand
    Reconfig and a macro Rename
    AlignedStruct
    Probe
    Embed
    Tunnel (TunnelAdapter is already implemented)

Add encodings support for the Strings

Convert the original unit tests to Perl (and make them pass...)

Fix the Graphics-EMF library

Add documentation to: ExtractingAdapter

Move the insertion of the parsed value to the context from the Struct/Sequence constructs
to each indevidual construct?

Streams: SocketStream

FileStreamWriter::Flush : improve.

Ability to give the CreateStreamReader/CreateStreamWriter function an ability to reconginze
socket / filehandle / pointer to string.

Union need to be extended to bit-structs?

add the stream object to the parser object? can be usefull with Pointer.

use some nice exception system

Find out if the EMF file should work or not. it fails on the statment:
Const(ULInt32("signature"), 0x464D4520)
And complain that it gets "0".

=head1 Thread Safety

This is a pure perl module. there should be not problems.

=head1 BUGS

None known

=head1 SEE ALSO

Original PyConstructs homepage: http://construct.wikispaces.com/

=head1 AUTHOR

Fomberg Shmuel, E<lt>owner@semuel.co.ilE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Shmuel Fomberg.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
