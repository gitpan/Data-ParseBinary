use strict;
use warnings;

package Data::ParseBinary::Stream::BitReader;
our @ISA = qw{Data::ParseBinary::Stream::Reader};

__PACKAGE__->_registerStreamType("Bit");

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


package Data::ParseBinary::Stream::BitWriter;
our @ISA = qw{Data::ParseBinary::Stream::Writer};

__PACKAGE__->_registerStreamType("Bit");

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
    return $self->{bs};
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