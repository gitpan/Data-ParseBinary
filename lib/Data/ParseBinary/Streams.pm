use strict;
use warnings;

package Data::ParseBinary::BitStream;

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
    my $bitData = $self->ReadBits($count * 8);
    my $data = pack "B*", $bitData;
    #print "BitStream: reading $count bytes\n";
    return $data;
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
    my $count = int($bitcount / 8) + ($bitcount % 8 ? 1 : 0);
    die "not enought bytes in stream" if $self->{location} + $count > $self->{length};
    my $data = substr($self->{data}, $self->{location}, $count);
    $self->{location} += $count;
    my $fullbits = unpack "B*", $data;
    my $string = substr($fullbits, -$bitcount);
    return $string;
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

package Data::ParseBinary::StringStreamWriter;

sub new {
    my ($class) = @_;
    my $self = {
        data => '',
    };
    return bless $self, $class;
}

sub WriteBytes {
    my ($self, $data) = @_;
    $self->{data} .= $data;
    return length $self->{data};
}

sub Flush {
    my $self = shift;
    return $self->{data};
}

sub isBitStream { return 0 };

1;