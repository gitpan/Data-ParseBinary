package Data::ParseBinary::Data::Netflow;

use strict;
use warnings;
use Data::ParseBinary;

our $netflow_v5_parser = Struct("nfv5_header",
	Const(UNInt16("version"), 5),
	UNInt16("count"),
	UNInt32("sys_uptime"),
	UNInt32("unix_secs"),
	UNInt32("unix_nsecs"),
	UNInt32("flow_seq"),
	UNInt8("engine_type"),
	UNInt8("engine_id"),
	Padding(2),
	Array(sub { $_->ctx->{count} },
		Struct("nfv5_record",
			Data::ParseBinary::lib::DataNetflow::IPAddr->create(
				UNInt32("src_addr")
			),
			Data::ParseBinary::lib::DataNetflow::IPAddr->create(
				UNInt32("dst_addr")
			),
			Data::ParseBinary::lib::DataNetflow::IPAddr->create(
			UNInt32("next_hop")
			),
			UNInt16("i_ifx"),
			UNInt16("o_ifx"),
			UNInt32("packets"),
			UNInt32("octets"),
			UNInt32("first"),
			UNInt32("last"),
			UNInt16("s_port"),
			UNInt16("d_port"),
			Padding(1),
			UNInt8("flags"),
			UNInt8("prot"),
			UNInt8("tos"),
			UNInt16("src_as"),
			UNInt16("dst_as"),
			UNInt8("src_mask"),
			UNInt8("dst_mask"),
			Padding(2)),
	),
);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw($netflow_v5_parser);

package Data::ParseBinary::lib::DataNetflow::IPAddr;

use Socket qw(inet_ntoa inet_aton);

our @ISA;
BEGIN { @ISA = qw{Data::ParseBinary::Adapter}; }

sub _decode {
	my ($self, $value) = @_;
	return inet_ntoa(pack('N',$value));
}

sub _encode {
	my ($self, $value) = @_;
	return sprintf("%d", unpack('N',inet_aton($value)));
}
1;

=head1 NAME

Data::ParseBinary::Data::Netflow - Parsing "Netflow" PDU binary structures.

=head1 SYNOPSIS

    use Data::ParseBinary::Data::Netflow qw($netflow_v5_parser);
	$data = $netflow_v5_parser->parse(CreateStreamReader(File => $fh));
	
Please note, that version 5 only supported now. ipackage Data::ParseBinary::Data::Netflow;
