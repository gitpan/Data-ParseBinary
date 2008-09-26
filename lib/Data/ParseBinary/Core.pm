use strict;
use warnings;

package Data::ParseBinary::BaseConstruct;

my $not_valid = 0;
my $string_data = 1;
my $file_data = 2;
our $DefaultPass;
my $print_debug_info;

sub create {
    my ($class, $name) = @_;
    return bless { Name => $name }, $class;
}

sub _get_name {
    my $self = shift;
    return $self->{Name};
}

sub _add_self {
    my ($self, $parser, $value) = @_;
    my $name = $self->_get_name();
    my $ctx = $parser->ctx();
    if (UNIVERSAL::isa($ctx, "HASH")) {
        $ctx->{$name} = $value;
    } elsif (UNIVERSAL::isa($ctx, "ARRAY")) {
        push @$ctx, $value;
    }
}

sub parse {
    my ($self, $data) = @_;
    {
        no warnings 'once';
        if (defined $Data::ParseBinary::print_debug_info) {
            $print_debug_info = -3;
        } else {
            $print_debug_info = undef;
        }
    }
    my $stream = Data::ParseBinary::Stream::Reader::CreateStreamReader($data);
    my $parser = Data::ParseBinary::Parser->new();
    return $self->_parse($parser, $stream);
}

sub _parse {
    my ($self, $parser, $stream) = @_;
    if (defined $print_debug_info) {
        $print_debug_info += 3;
        print " " x $print_debug_info;
        print "Parsing ", ref($self);
        my $name = $self->_get_name();
        print " Named ", (defined $name ? $name : "undef"), "\n";
    }
    my $ret = $self->__parse($parser, $stream);
    if (defined $print_debug_info) {
        $print_debug_info -= 3;
    }
    return $ret;
}

sub __parse {
    my ($self, $parser, $stream) = @_;
    die "Bad Shmuel: sub __parse was not implemented for " . ref($self);
}

sub build {
    my ($self, $data, $source_stream) = @_;
    my $stream = Data::ParseBinary::Stream::Writer::CreateStreamWriter($source_stream);
    my $parser = Data::ParseBinary::Parser->new();
    $self->_build($parser, $stream, $data);
    return $stream->Flush();
}

sub _build {
    my ($self, $parser, $stream, $data) = @_;
    die "Bad Shmuel: sub _build was not implemented for " . ref($self);
}

sub _size_of {
    my ($self, $context) = @_;
    die "This Construct (".ref($self).") does not know his own size";
}

package Data::ParseBinary::WrappingConstruct;
our @ISA = qw{Data::ParseBinary::BaseConstruct};

sub create {
    my ($class, $subcon) = @_;
    my $self = $class->SUPER::create($subcon->_get_name());
    $self->{subcon} = $subcon;
    return $self;
}

sub subcon {
    my $self = shift;
    return $self->{subcon};
}

sub __parse {
    my ($self, $parser, $stream) = @_;
    return $self->{subcon}->_parse($parser, $stream);
}

sub _build {
    my ($self, $parser, $stream, $data) = @_;
    return $self->{subcon}->_build($parser, $stream, $data);
}

sub _size_of {
    my ($self, $context) = @_;
    return $self->{subcon}->_size_of($context);
}

package Data::ParseBinary::Adapter;
our @ISA = qw{Data::ParseBinary::WrappingConstruct};

sub create {
    my ($class, $subcon, @params) = @_;
    my $self = $class->SUPER::create($subcon);
    $self->_init(@params);
    return $self;
}

sub _init {
    my ($self, @params) = @_;
}

sub __parse {
    my ($self, $parser, $stream) = @_;
    my $value = $self->{subcon}->_parse($parser, $stream);
    my $tvalue = $self->_decode($value);
    return $tvalue;
}

sub _build {
    my ($self, $parser, $stream, $data) = @_;
    my $value = $self->_encode($data);
    $self->{subcon}->_build($parser, $stream, $value);
}

sub _decode {
    my ($self, $value) = @_;
    die "An Adapter class should override the _decode sub";
    #my $tvalue = transform($value);
    #return $tvalue;
}

sub _encode {
    my ($self, $tvalue) = @_;
    die "An Adapter class should override the _decode sub";
    #my $value = transform($tvalue);
    #return $value;
}

package Data::ParseBinary::Validator;
our @ISA = qw{Data::ParseBinary::Adapter};

sub _decode {
    my ($self, $value) = @_;
    die "Validator error at " . $self->_get_name() unless $self->_validate($value);
    return $value;
}

sub _encode {
    my ($self, $tvalue) = @_;
    die "Validator error at " . $self->_get_name() unless $self->_validate($tvalue);
    return $tvalue;
}

sub _validate {
    my ($self, $value) = @_;
    die "An Validator class should override the _validate sub";
}

package Data::ParseBinary::Parser;

sub new {
    my ($class) = @_;
    return bless {ctx=>[], obj=>undef}, $class;
}

sub obj {
    my $self = shift;
    return $self->{obj};
}

sub set_obj {
    my ($self, $new_obj) = @_;
    $self->{obj} = $new_obj;
}

sub ctx {
    my ($self, $level) = @_;
    $level ||= 0;
    die "Parser: ctx level $level does not exists" if $level >= scalar @{ $self->{ctx} };
    return $self->{ctx}->[$level];
}

sub push_ctx {
    my ($self, $new_ctx) = @_;
    unshift @{ $self->{ctx} }, $new_ctx;
}

sub pop_ctx {
    my $self = shift;
    return shift @{ $self->{ctx} };
}

1;