package Data::ParseBinary::lib::DataCap;
use strict;
use warnings;
use Data::ParseBinary;
#"""
#tcpdump capture file
#"""


my $packet = Struct("packet",
    Data::ParseBinary::lib::DataCap::MicrosecAdapter->create(
        Sequence("time", 
            ULInt32("time"),
            ULInt32("usec"),
        )
    ),
    ULInt32("length"),
    Padding(4),
    Field("data", sub { $_->ctx->{length} }),
);

my $cap_file = Struct("cap_file",
    Padding(24),
    OptionalGreedyRange($packet),
);

our $Parser = $cap_file;

package Data::ParseBinary::lib::DataCap::MicrosecAdapter;
our @ISA;
BEGIN { @ISA = qw{Data::ParseBinary::Adapter}; }

sub _decode {
    my ($self, $value) = @_;
    return sprintf("%d.%06d", @$value)
}

sub _encode {
    my ($self, $tvalue) = @_;
    if ( index($tvalue, ".") >= 0 ) {
        my ($sec, $usec) = $tvalue =~ /^(\d+)\.(\d*)$/;
        if (length($usec) > 6) {
            $usec = substr($usec, 0, 6);
        } else {
            $usec .= "0" x (6 - length($usec));
        }
        return [$sec, $usec];
    } else {
        return [$tvalue, 0];
    }
}
    #def _decode(self, obj, context):
    #    return datetime.fromtimestamp(obj[0] + (obj[1] / 1000000.0))
    #def _encode(self, obj, context):
    #    offset = time.mktime(*obj.timetuple())
    #    sec = int(offset)
    #    usec = (offset - sec) * 1000000
    #    return (sec, usec)


1;
