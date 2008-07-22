package Data::ParseBinary::StreamReader;
use strict;
use warnings;

sub _readBitsForByteStream {
    my ($self, $bitcount) = @_;
    my $count = int($bitcount / 8) + ($bitcount % 8 ? 1 : 0);
    my $data = $self->ReadBytes($count);
    my $fullbits = unpack "B*", $data;
    my $string = substr($fullbits, -$bitcount);
    return $string;
}

sub _readBytesForBitStream {
    my ($self, $count) = @_;
    my $bitData = $self->ReadBits($count * 8);
    my $data = pack "B*", $bitData;
    return $data;
}

sub isBitStream { die "unimplemented" }
sub ReadBytes { die "unimplemented" }
sub ReadBits { die "unimplemented" }
sub seek { die "unimplemented" }
sub tell { die "unimplemented" }

package Data::ParseBinary::FileStreamReader;
our @ISA = qw{Data::ParseBinary::StreamReader};

sub new {
    my ($class, $fh) = @_;
    my $self = {
        handle => $fh,
    };
    return bless $self, $class;
}

sub ReadBytes {
    my ($self, $count) = @_;
    my $buf = '';
    read($self->{handle}, $buf, $count);
    return $buf;
}

sub ReadBits {
    my ($self, $bitcount) = @_;
    return $self->_readBitsForByteStream($bitcount);
}

sub tell {
    my $self = shift;
    return CORE::tell($self->{handle});
}

sub seek {
    my ($self, $newpos) = @_;
    CORE::seek($self->{handle}, $newpos, 0);
}

sub isBitStream { return 0 };

package Data::ParseBinary::BitStreamReader;
our @ISA = qw{Data::ParseBinary::StreamReader};

sub new {
    my ($class, $byteStream) = @_;
    my $self = {
        bs => $byteStream,
        buffer => '',
    };
    return bless $self, $class;
}

sub ReadBytes {
    my ($self, $count) = @_;
    return $self->_readBytesForBitStream($count);
}

sub ReadBits {
    my ($self, $bitcount) = @_;
    my $current = $self->{buffer};
    my $moreBitsNeeded = $bitcount - length($current);
    $moreBitsNeeded = 0 if $moreBitsNeeded < 0;
    my $moreBytesNeeded = int($moreBitsNeeded / 8) + ($moreBitsNeeded % 8 ? 1 : 0);
    #print "BitStream: $bitcount bits requested, $moreBytesNeeded bytes read\n";
    my $string = $self->{bs}->ReadBytes($moreBytesNeeded);
    $current .= unpack "B*", $string;
    my $data = substr($current, 0, $bitcount, '');
    $self->{buffer} = $current;
    return $data;
}

sub tell {
    my $self = shift;
    die "A bit stream is not seekable";
}

sub seek {
    my ($self, $newpos) = @_;
    die "A bit stream is not seekable";
}

sub isBitStream { return 1 };

package Data::ParseBinary::StringStreamReader;
our @ISA = qw{Data::ParseBinary::StreamReader};

sub new {
    my ($class, $string) = @_;
    my $self = {
        data => $string,
        location => 0,
        length => length($string),
    };
    return bless $self, $class;
}

sub ReadBytes {
    my ($self, $count) = @_;
    die "not enought bytes in stream" if $self->{location} + $count > $self->{length};
    my $data = substr($self->{data}, $self->{location}, $count);
    $self->{location} += $count;
    return $data;
}

sub ReadBits {
    my ($self, $bitcount) = @_;
    return $self->_readBitsForByteStream($bitcount);
}

sub tell {
    my $self = shift;
    return $self->{location};
}

sub seek {
    my ($self, $newpos) = @_;
    die "can not seek past string's end" if $newpos > $self->{length};
    $self->{location} = $newpos;
}

sub isBitStream { return 0 };


package Data::ParseBinary::StreamWriter;

sub WriteBytes { die "unimplemented" }
sub WriteBits { die "unimplemented" }
sub Flush { die "unimplemented" }
sub isBitStream { die "unimplemented" }
sub seek { die "unimplemented" }
sub tell { die "unimplemented" }

sub _writeBitsForByteStream {
    my ($self, $bitdata) = @_;
    my $data_len = length($bitdata);
    my $zeros_to_add = (-$data_len) % 8;
    my $binary = pack "B".($zeros_to_add + $data_len), ('0'x$zeros_to_add).$bitdata;
    return $self->WriteBytes($binary);
}

sub _writeBytesForBitStream {
    my ($self, $data) = @_;
    my $bitdata = unpack "B*", $data;
    return $self->WriteBits($bitdata);
}


package Data::ParseBinary::StringStreamWriter;
our @ISA = qw{Data::ParseBinary::StreamWriter};

sub new {
    my ($class) = @_;
    my $self = {
        data => '',
        offset => 0, # minus bytes from the end
    };
    return bless $self, $class;
}

sub tell {
    my $self = shift;
    return length($self->{data}) - $self->{offset};
}

sub seek {
    my ($self, $newpos) = @_;
    if ($newpos > length($self->{data})) {
        $self->{offset} = 0;
        $self->{data} .= "\0" x ($newpos - length($self->{data}))
    } else {
        $self->{offset} = length($self->{data}) - $newpos;
    }
}

sub WriteBytes {
    my ($self, $data) = @_;
    if ($self->{offset} == 0) {
        $self->{data} .= $data;
        return length $self->{data};
    }
    substr($self->{data}, -$self->{offset}, length($data), $data);
    if ($self->{offset} <= length($data)) {
        $self->{offset} = 0;
    } else {
        $self->{offset} = $self->{offset} - length($data);
    }
    return length($self->{data}) - $self->{offset};
}

sub WriteBits {
    my ($self, $bitdata) = @_;
    return $self->_writeBitsForByteStream($bitdata);
}

sub Flush {
    my $self = shift;
    return $self->{data};
}

sub isBitStream { return 0 };

package Data::ParseBinary::BitStreamWriter;
our @ISA = qw{Data::ParseBinary::StreamWriter};

sub new {
    my ($class, $byteStream) = @_;
    my $self = {
        bs => $byteStream,
        buffer => '',
    };
    return bless $self, $class;
}

sub WriteBytes {
    my ($self, $data) = @_;
    return $self->_writeBytesForBitStream($data);
}

sub WriteBits {
    my ($self, $bitdata) = @_;
    my $current = $self->{buffer};
    my $new_buffer = $current . $bitdata;
    my $numof_bytesToWrite = int(length($new_buffer) / 8);
    my $bytesToWrite = substr($new_buffer, 0, $numof_bytesToWrite * 8, '');
    my $binaryToWrite = pack "B".($numof_bytesToWrite * 8), $bytesToWrite;
    $self->{buffer} = $new_buffer;
    return $self->{bs}->WriteBytes($binaryToWrite);
}

sub Flush {
    my $self = shift;
    my $write_size = (-length($self->{buffer})) % 8;
    $self->WriteBits('0'x$write_size);
}

sub tell {
    my $self = shift;
    die "A bit stream is not seekable";
}

sub seek {
    my ($self, $newpos) = @_;
    die "A bit stream is not seekable";
}

sub isBitStream { return 1 };

1;