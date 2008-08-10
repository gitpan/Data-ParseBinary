use strict;
use warnings;

package Data::ParseBinary::Stream::WarperReader;
our @ISA = qw{Data::ParseBinary::Stream::Reader};

__PACKAGE__->_registerStreamType("Warp");

sub new {
    my ($class, $sub_stream) = @_;
    return bless { ss => $sub_stream }, $class;
}

sub ReadBytes { my $self = shift; $self->{ss}->ReadBytes(@_);  }
sub ReadBits { my $self = shift; $self->{ss}->ReadBits(@_); }
sub isBitStream { my $self = shift; $self->{ss}->isBitStream(@_); }
sub seek { my $self = shift; $self->{ss}->seek(@_); }
sub tell { my $self = shift; $self->{ss}->tell(@_); }

package Data::ParseBinary::Stream::WarperWriter;
our @ISA = qw{Data::ParseBinary::Stream::Writer};

__PACKAGE__->_registerStreamType("Warp");

sub new {
    my ($class, $sub_stream) = @_;
    return bless { ss => $sub_stream }, $class;
}

sub WriteBytes { my $self = shift; $self->{ss}->WriteBytes(@_);  }
sub WriteBits { my $self = shift; $self->{ss}->WriteBits(@_); }
sub Flush { my $self = shift; return $self->{ss} }
sub isBitStream { my $self = shift; $self->{ss}->isBitStream(@_); }
sub seek { my $self = shift; $self->{ss}->seek(@_); }
sub tell { my $self = shift; $self->{ss}->tell(@_); }

1;