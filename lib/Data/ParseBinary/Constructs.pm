package Data::ParseBinary::Constructs;

use strict;
use warnings;

our $DefaultPass = [];

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
    $DefaultPass
);

package Data::ParseBinary::Union;
our @ISA = qw{Data::ParseBinary::BaseConstruct};

sub create {
    my ($class, $name, @subcons) = @_;
    my $self = $class->SUPER::create($name);
    my $size = $subcons[0]->_size_of();
    foreach my $sub (@subcons) {
        my $temp_size = $sub->_size_of();
        $size = $temp_size if $temp_size > $size;
    }
    $self->{subcons} = \@subcons;
    $self->{size} = $size;
    return $self;
}

sub _parse {
    my ($self, $parser, $stream) = @_;
    my $hash = {};
    $parser->push_ctx($hash);
    my $pos = $stream->tell();
    foreach my $sub (@{ $self->{subcons} }) {
        my $name = $sub->_get_name();
        my $value = $sub->_parse($parser, $stream);
        $stream->seek($pos);
        next unless defined $name;
        $hash->{$name} = $value;
    }
    $stream->ReadBytes($self->{size});
    $parser->pop_ctx();
    return $hash;
}

sub _build {
    my ($self, $parser, $stream, $data) = @_;
    foreach my $sub (@{ $self->{subcons} }) {
        my $name = $sub->_get_name();
        next unless exists $data->{$name} and defined $data->{$name};
        $sub->_build($parser, $stream, $data->{$name});
        if ($self->{size} > $sub->_size_of()) {
            $stream->WriteBytes("\0" x ( $self->{size} - $sub->_size_of() ));
        }
        return;
    }
    die "Union build error: not found any data";
}

package Data::ParseBinary::TunnelAdapter;
our @ISA = qw{Data::ParseBinary::WarpingConstruct};

sub create {
    my ($class, $subcon, $inner_subcon) = @_;
    my $self = $class->SUPER::create($subcon);
    $self->{inner_subcon} = $inner_subcon;
    return $self;
}

sub _parse {
    my ($self, $parser, $stream) = @_;
    my $inter = $self->{subcon}->_parse($parser, $stream);
    my $inter_stream = Data::ParseBinary::StringStreamReader->new($inter);
    return $self->{inner_subcon}->_parse($parser, $inter_stream);
}

sub _build {
    my ($self, $parser, $stream, $data) = @_;
    my $inter_stream = Data::ParseBinary::StringStreamWriter->new();
    $self->{inner_subcon}->_build($parser, $inter_stream, $data);
    my $tdata = $inter_stream->Flush();
    $self->{subcon}->_build($parser, $stream, $tdata);
}

package Data::ParseBinary::Peek;
our @ISA = qw{Data::ParseBinary::WarpingConstruct};

sub create {
    my ($class, $subcon, $perform_build) = @_;
    my $self = $class->SUPER::create($subcon);
    $self->{perform_build} = $perform_build;
    return $self;
}

sub _parse {
    my ($self, $parser, $stream) = @_;
    my $pos = $stream->tell();
    my $res;
    eval {
        $res = $self->{subcon}->_parse($parser, $stream);
    };
    if ($@) {
        $res = undef;
    }
    $stream->seek($pos);
    return $res;
}

sub _build {
    my ($self, $parser, $stream, $data) = @_;
    if ($self->{perform_build}) {
        $self->{subcon}->_build($parser, $stream, $data);
    }
}

package Data::ParseBinary::Value;
our @ISA = qw{Data::ParseBinary::BaseConstruct};

sub create {
    my ($class, $name, $func) = @_;
    my $self = $class->SUPER::create($name);
    $self->{func} = $func;
    return $self;
}

sub _getValue {
    my ($self, $parser) = @_;
    local $_ = $parser;
    return $self->{func}->();
}

sub _parse {
    my ($self, $parser, $stream) = @_;
    return $self->_getValue($parser);
}

sub _build {
    my ($self, $parser, $stream, $data) = @_;
    $parser->ctx->{$self->_get_name()} = $self->_getValue($parser);
}

package Data::ParseBinary::LazyBound;
our @ISA = qw{Data::ParseBinary::BaseConstruct};

sub create {
    my ($class, $name, $boundfunc) = @_;
    my $self = $class->SUPER::create($name);
    $self->{bound} = undef;
    $self->{boundfunc} = $boundfunc;
    return $self;
}

sub _getBound {
    my ($self, $parser) = @_;
    return $self->{bound} if $self->{bound};
    local $_ = $parser;
    $self->{bound} = $self->{boundfunc}->();
    return $self->{bound};
}

sub _parse {
    my ($self, $parser, $stream) = @_;
    return $self->_getBound($parser)->_parse($parser, $stream);
}

sub _build {
    my ($self, $parser, $stream, $data) = @_;
    return $self->_getBound($parser)->_build($parser, $stream, $data);
}

package Data::ParseBinary::Terminator;
our @ISA = qw{Data::ParseBinary::BaseConstruct};

sub _parse {
    my ($self, $parser, $stream) = @_;
    eval { $stream->ReadBytes(1) };
    if (not $@) {
        die "Terminator expected end of stream";
    }
    return;
}

sub _build {
    my ($self, $parser, $stream, $data) = @_;
    return;
}

package Data::ParseBinary::NullConstruct;
our @ISA = qw{Data::ParseBinary::BaseConstruct};

sub _parse {
    my ($self, $parser, $stream) = @_;
    return;
}

sub _build {
    my ($self, $parser, $stream, $data) = @_;
    return;
}

package Data::ParseBinary::Pointer;
our @ISA = qw{Data::ParseBinary::BaseConstruct};

sub create {
    my ($class, $posfunc, $subcon) = @_;
    my $self = $class->SUPER::create($subcon->_get_name());
    $self->{subcon} = $subcon;
    $self->{posfunc} = $posfunc;
    return $self;
}

sub _getPos {
    my ($self, $parser) = @_;
    local $_ = $parser;
    $self->{posfunc}->();
}

sub _parse {
    my ($self, $parser, $stream) = @_;
    my $newpos = $self->_getPos($parser);
    my $origpos = $stream->tell();
    $stream->seek($newpos);
    my $value = $self->{subcon}->_parse($parser, $stream);
    $stream->seek($origpos);
    return $value;
}

sub _build {
    my ($self, $parser, $stream, $data) = @_;
    my $newpos = $self->_getPos($parser);
    my $origpos = $stream->tell();
    stream->seek($newpos);
    $self->{subcon}->parse($parser, $stream, $data);
    $stream->seek($origpos);
}

package Data::ParseBinary::Anchor;
our @ISA = qw{Data::ParseBinary::BaseConstruct};

sub _parse {
    my ($self, $parser, $stream) = @_;
    return $stream->tell();
}

sub _build {
    my ($self, $parser, $stream, $data) = @_;
    my $context = $parser->ctx(0);
    die "Anchor can not be on it's on" unless defined $context;
    $context->{$self->_get_name()} = $stream->tell();
}

package Data::ParseBinary::Switch;
our @ISA = qw{Data::ParseBinary::BaseConstruct};

sub create {
    my ($class, $name, $keyfunc, $cases, %params) = @_;
    die "Switch expects code ref as keyfunc"
        unless $keyfunc and ref($keyfunc) and UNIVERSAL::isa($keyfunc, "CODE");
    die "Switch expects hash-ref as a list of cases"
        unless $cases and ref($cases) and UNIVERSAL::isa($cases, "HASH");
    my $self = $class->SUPER::create($name);
    $self->{keyfunc} = $keyfunc;
    $self->{cases} = $cases;
    $self->{default} = $params{default};
    $self->{default} = Data::ParseBinary::NullConstruct->create() if $self->{default} and $self->{default} == $DefaultPass; 
    return $self;
}

sub _getCont {
    my ($self, $parser) = @_;
    local $_ = $parser;
    my $key = $self->{keyfunc}->();
    if (exists $self->{cases}->{$key}) {
        return $self->{cases}->{$key};
    }
    if (defined $self->{default}) {
        return $self->{default};
    }
    die "Error at Switch: got un-declared value, and no default was defined";
}

sub _parse {
    my ($self, $parser, $stream) = @_;
    my $value = $self->_getCont($parser);
    return unless defined $value;
    return $value->_parse($parser, $stream);
}

sub _build {
    my ($self, $parser, $stream, $data) = @_;
    my $value = $self->_getCont($parser);
    return unless defined $value;
    return $value->_build($parser, $stream, $data);
}


package Data::ParseBinary::StaticField;
our @ISA = qw{Data::ParseBinary::BaseConstruct};

sub create {
    my ($class, $name, $len) = @_;
    my $self = $class->SUPER::create($name);
    $self->{len} = $len;
    return $self;
}

sub _parse {
    my ($self, $parser, $stream) = @_;
    my $data = $stream->ReadBytes($self->{len});
    return $data;
}

sub _build {
    my ($self, $parser, $stream, $data) = @_;
    die "Invalid Value" unless defined $data and not ref $data;
    $stream->WriteBytes($data);
}

package Data::ParseBinary::MetaField;
our @ISA = qw{Data::ParseBinary::BaseConstruct};

sub create {
    my ($class, $name, $coderef) = @_;
    die "MetaField $name: must have a coderef" unless ref($coderef) and UNIVERSAL::isa($coderef, "CODE");
    my $self = $class->SUPER::create($name);
    $self->{code} = $coderef;
    return $self;
}

sub _getLength {
    my ($self, $parser) = @_;
    local $_ = $parser;
    return $self->{code}->();
}

sub _parse {
    my ($self, $parser, $stream) = @_;
    my $len = $self->_getLength($parser);
    my $data = $stream->ReadBytes($len);
    return $data;
}

sub _build {
    my ($self, $parser, $stream, $data) = @_;
    die "Invalid Value" unless defined $data and not ref $data;
    $stream->WriteBytes($data);
}

package Data::ParseBinary::Enum;
our @ISA = qw{Data::ParseBinary::Adapter};
# TODO: implement as macro in terms of SymmetricMapping (macro)
#   that is implemented as MappingAdapter

sub _init {
    my ($self, @params) = @_;
    my $decode = {};
    my $encode = {};
    my $have_default = 0;
    my $default_action = undef;
    while (@params) {
        my $key = shift @params;
        my $value = shift @params;
        if ($key eq '_default_') {
            $have_default = 1;
            $default_action = $value;
            if (ref($default_action) and $default_action == $DefaultPass) {
                $default_action = $DefaultPass;
            }
            next;
        }
        $encode->{$key} = $value;
        $decode->{$value} = $key;
    }
    $self->{encode} = $encode;
    $self->{decode} = $decode;
    $self->{have_default} = $have_default;
    $self->{default_action} = $default_action;
}

sub _decode {
    my ($self, $value) = @_;
    if (exists $self->{decode}->{$value}) {
        return $self->{decode}->{$value};
    }
    if ($self->{have_default}) {
        if (ref($self->{default_action}) and $self->{default_action} == $DefaultPass) {
            return $value;
        }
        return $self->{default_action};
    }
    die "Enum: unrecognized value $value, and no default defined";
}

sub _encode {
    my ($self, $tvalue) = @_;
    if (exists $self->{encode}->{$tvalue}) {
        return $self->{encode}->{$tvalue};
    }
    die "Enum: unrecognized value $tvalue";
}

package Data::ParseBinary::BitStruct;
our @ISA = qw{Data::ParseBinary::BaseConstruct};

sub create {
    my ($class, $name, @subconstructs) = @_;
    die "Empty BitStruct is illigal" unless @subconstructs;
    my $self = $class->SUPER::create($name);
    $self->{subs} = \@subconstructs;
    return $self;
}

sub _parse {
    my ($self, $parser, $stream) = @_;
    die "BitStruct can not be nested" if $stream->isBitStream();
    my $subStream = Data::ParseBinary::BitStream->new($stream);
    my $hash = {};
    $parser->push_ctx($hash);
    foreach my $sub (@{ $self->{subs} }) {
        my $name = $sub->_get_name();
        my $value = $sub->_parse($parser, $subStream);
        next unless defined $name;
        $hash->{$name} = $value;
    }
    $parser->pop_ctx();
    return $hash;
}


sub _build {
    my ($self, $parser, $stream, $data) = @_;
    die "BitStruct can not be nested" if $stream->isBitStream();
    die "Invalid Struct Value" unless defined $data and ref $data and UNIVERSAL::isa($data, "HASH");
    my $subStream = Data::ParseBinary::BitStream->new($stream);
    $parser->push_ctx($data);
    foreach my $sub (@{ $self->{subs} }) {
        my $name = $sub->_get_name();
        die "Struct " . $self->_get_name() . " expects child named $name"
            unless exists $data->{$name} and defined $data->{$name};
        $sub->_build($parser, $subStream, $data->{$name});
    }
    $parser->pop_ctx();
}

package Data::ParseBinary::BitField;
our @ISA = qw{Data::ParseBinary::BaseConstruct};

sub create {
    my ($class, $name, $length) = @_;
    my $self = $class->SUPER::create($name);
    $self->{length} = $length;
    return $self;
}

sub _parse {
    my ($self, $parser, $stream) = @_;
    my $data = $stream->ReadBits($self->{length});
    my $pad_len = 32 - $self->{length};
    my $parsed = unpack "N", pack "B32", ('0' x $pad_len) . $data;
    return $parsed;
}

sub _build {
    my ($self, $parser, $stream, $data) = @_;
    my $string = unpack "B".$self->{length}, $data;
    $stream->WriteBits($string);
}

package Data::ParseBinary::Padding;
our @ISA = qw{Data::ParseBinary::BaseConstruct};

sub create {
    my ($class, $count) = @_;
    my $self = $class->SUPER::create(undef);
    if (ref($count) and UNIVERSAL::isa($count, "CODE")) {
        $self->{count_code} = $count;
    } else {
        $self->{count} = $count;
    }
    return $self;
}

sub _getCount {
    my ($self, $parser) = @_;
    return $self->{count} unless defined $self->{count_code};
    local $_ = $parser;
    $self->{count_code}->();
}

sub _parse {
    my ($self, $parser, $stream) = @_;
    if ($stream->isBitStream()) {
        $stream->ReadBits($self->_getCount($parser));
    } else {
        $stream->ReadBytes($self->_getCount($parser));
    }
}

sub _build {
    my ($self, $parser, $stream, $data) = @_;
    if ($stream->isBitStream()) {
        $stream->WriteBits("0" x $self->_getCount($parser));
    } else {
        $stream->WriteBytes("\0" x $self->_getCount($parser));
    }
}

package Data::ParseBinary::RepeatUntil;
our @ISA = qw{Data::ParseBinary::BaseConstruct};

sub create {
    my ($class, $coderef, $sub) = @_;
    die "Empty MetaArray is illigal" unless $sub and $coderef;
    die "MetaArray must have a sub-construct" unless ref $sub and UNIVERSAL::isa($sub, "Data::ParseBinary::BaseConstruct");
    die "MetaArray must have a length code ref" unless ref $coderef and UNIVERSAL::isa($coderef, "CODE");
    my $name =$sub->_get_name();
    my $self = $class->SUPER::create($name);
    $self->{sub} = $sub;
    $self->{len_code} = $coderef;
    return $self;
}

sub _shouldStop {
    my ($self, $parser, $value) = @_;
    local $_ = $parser;
    $parser->set_obj($value);
    my $ret = $self->{len_code}->();
    $parser->set_obj(undef);
    return $ret;
}

sub _parse {
    my ($self, $parser, $stream) = @_;
    my $list = [];
    $parser->push_ctx($list);
    while (1) {
        my $value = $self->{sub}->_parse($parser, $stream);
        push @$list, $value;
        last if $self->_shouldStop($parser, $value);
    }
    $parser->pop_ctx();
    return $list;
}

sub _build {
    my ($self, $parser, $stream, $data) = @_;
    die "Invalid Sequence Value" unless defined $data and ref $data and UNIVERSAL::isa($data, "ARRAY");
    
    $parser->push_ctx($data);
    for my $item (@$data) {
        $self->{sub}->_build($parser, $stream, $item);
        last if $self->_shouldStop($parser, $item);
    }
    $parser->pop_ctx();
}

package Data::ParseBinary::MetaArray;
our @ISA = qw{Data::ParseBinary::BaseConstruct};

sub create {
    my ($class, $coderef, $sub) = @_;
    die "Empty MetaArray is illigal" unless $sub and $coderef;
    die "MetaArray must have a sub-construct" unless ref $sub and UNIVERSAL::isa($sub, "Data::ParseBinary::BaseConstruct");
    die "MetaArray must have a length code ref" unless ref $coderef and UNIVERSAL::isa($coderef, "CODE");
    my $name =$sub->_get_name();
    my $self = $class->SUPER::create($name);
    $self->{sub} = $sub;
    $self->{len_code} = $coderef;
    return $self;
}

sub _getLength {
    my ($self, $parser) = @_;
    local $_ = $parser;
    return $self->{len_code}->();
}

sub _parse {
    my ($self, $parser, $stream) = @_;
    my $len = $self->_getLength($parser);
    my $list = [];
    $parser->push_ctx($list);
    for my $ix (1..$len) {
        my $value = $self->{sub}->_parse($parser, $stream);
        push @$list, $value;
    }
    $parser->pop_ctx();
    return $list;
}

sub _build {
    my ($self, $parser, $stream, $data) = @_;
    die "Invalid Sequence Value" unless defined $data and ref $data and UNIVERSAL::isa($data, "ARRAY");
    my $len = $self->_getLength($parser);
    
    die "Invalid Sequence Length" if @$data != $len;
    $parser->push_ctx($data);
    for my $item (@$data) {
        $self->{sub}->_build($parser, $stream, $item);
    }
    $parser->pop_ctx();
}

package Data::ParseBinary::Range;
our @ISA = qw{Data::ParseBinary::BaseConstruct};

sub create {
    my ($class, $min, $max, $sub) = @_;
    die "Empty Struct is illigal" unless $sub;
    die "Repeater must have a sub-construct" unless ref $sub and UNIVERSAL::isa($sub, "Data::ParseBinary::BaseConstruct");
    my $name =$sub->_get_name();
    my $self = $class->SUPER::create($name);
    $self->{sub} = $sub;
    $self->{max} = $max;
    $self->{min} = $min;
    return $self;
}

sub _parse {
    my ($self, $parser, $stream) = @_;
    my $list = [];
    $parser->push_ctx($list);
    my $max = $self->{max};
    if (defined $max) {
        for my $ix (1..$max) {
            my $value;
            eval {
                $value = $self->{sub}->_parse($parser, $stream);
            };
            if ($@) {
                die $@ if $ix <= $self->{min};
                last;
            }
            push @$list, $value;
        }
    } else {
        my $ix = 0;
        while (1) {
            $ix++;
            my $value;
            eval {
                $value = $self->{sub}->_parse($parser, $stream);
            };
            if ($@) {
                die $@ if $ix <= $self->{min};
                last;
            }
            push @$list, $value;
        }
    }
    $parser->pop_ctx();
    return $list;
}

sub _build {
    my ($self, $parser, $stream, $data) = @_;
    die "Invalid Sequence Value" unless defined $data and ref $data and UNIVERSAL::isa($data, "ARRAY");
    die "Invalid Sequence Length (min)" if @$data < $self->{min};
    die "Invalid Sequence Length (max)" if defined $self->{max} and @$data > $self->{max};
    $parser->push_ctx($data);
    for my $item (@$data) {
        $self->{sub}->_build($parser, $stream, $item);
    }
    $parser->pop_ctx();
}

package Data::ParseBinary::Sequence;
our @ISA = qw{Data::ParseBinary::BaseConstruct};

sub create {
    my ($class, $name, @subconstructs) = @_;
    die "Empty Struct is illigal" unless @subconstructs;
    my $self = $class->SUPER::create($name);
    $self->{subs} = \@subconstructs;
    return $self;
}

sub _parse {
    my ($self, $parser, $stream) = @_;
    my $list = [];
    $parser->push_ctx($list);
    foreach my $sub (@{ $self->{subs} }) {
        my $name = $sub->_get_name();
        my $value = $sub->_parse($parser, $stream);
        push @$list, $value;
    }
    $parser->pop_ctx();
    return $list;
}


sub _build {
    my ($self, $parser, $stream, $data) = @_;
    die "Invalid Sequence Value" unless defined $data and ref $data and UNIVERSAL::isa($data, "ARRAY");
    die "Invalid Sequence Length" unless @$data == @{ $self->{subs} };
    $parser->push_ctx($data);
    for my $ix (0..$#$data) {
        my $sub = $self->{subs}->[$ix];
        my $name = $sub->_get_name();
        $sub->_build($parser, $stream, $data->[$ix]);
    }
    $parser->pop_ctx();
}

package Data::ParseBinary::Struct;
our @ISA = qw{Data::ParseBinary::BaseConstruct};

sub create {
    my ($class, $name, @subconstructs) = @_;
    die "Empty Struct is illigal" unless @subconstructs;
    my $self = $class->SUPER::create($name);
    $self->{subs} = \@subconstructs;
    return $self;
}


sub _parse {
    my ($self, $parser, $stream) = @_;
    my $hash = {};
    $parser->push_ctx($hash);
    foreach my $sub (@{ $self->{subs} }) {
        my $name = $sub->_get_name();
        my $value = $sub->_parse($parser, $stream);
        next unless defined $name;
        $hash->{$name} = $value;
    }
    $parser->pop_ctx();
    return $hash;
}


sub _build {
    my ($self, $parser, $stream, $data) = @_;
    die "Invalid Struct Value" unless defined $data and ref $data and UNIVERSAL::isa($data, "HASH");
    $parser->push_ctx($data);
    foreach my $sub (@{ $self->{subs} }) {
        my $name = $sub->_get_name();
        $sub->_build($parser, $stream, $data->{$name});
    }
    $parser->pop_ctx();
}

package Data::ParseBinary::Primitive;
our @ISA = qw{Data::ParseBinary::BaseConstruct};

sub create {
    my ($class, $name, $sizeof, $pack_param) = @_;
    my $self = $class->SUPER::create($name);
    $self->{sizeof} = $sizeof;
    $self->{pack_param} = $pack_param;
    return $self;
}

sub _parse {
    my ($self, $parser, $stream) = @_;
    my $data = $stream->ReadBytes($self->{sizeof});
    my $number = unpack $self->{pack_param}, $data;
    return $number;
}

sub _build {
    my ($self, $parser, $stream, $data) = @_;
    die "Invalid Primitive Value" unless defined $data and not ref $data;
    my $string = pack $self->{pack_param}, $data;
    $stream->WriteBytes($string);
}

sub _size_of {
    my ($self, $context) = @_;
    return $self->{sizeof};
}

package Data::ParseBinary::ReveresedPrimitive;
our @ISA = qw{Data::ParseBinary::Primitive};

sub _parse {
    my ($self, $parser, $stream) = @_;
    my $data = $stream->ReadBytes($self->{sizeof});
    my $r_data = join '', reverse split '', $data;
    my $number = unpack $self->{pack_param}, $r_data;
    return $number;
}

sub _build {
    my ($self, $parser, $stream, $data) = @_;
    my $string = pack $self->{pack_param}, $data;
    my $r_string = join '', reverse split '', $string;
    $stream->WriteBytes($r_string);
}

sub _size_of {
    my ($self, $context) = @_;
    return $self->{sizeof};
}

1;