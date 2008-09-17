use strict;
use warnings;
use Data::ParseBinary::Core;

package Data::ParseBinary::FlagsEnum;
our @ISA = qw{Data::ParseBinary::Adapter};

sub _init {
    my ($self, @mapping) = @_;
    my @pairs;
    die "FlagsEnum: Mapping should be even" if @mapping % 2 == 1;
    while (@mapping) {
        my $name = shift @mapping;
        my $value = shift @mapping;
        push @pairs, [$name, $value];
    }
    $self->{pairs} = \@pairs;
}

sub _decode {
    my ($self, $value) = @_;
    my $hash = {};
    foreach my $rec (@{ $self->{pairs} }) {
        $hash->{$rec->[0]} = 1 if $value | $rec->[1];
    }
    return $hash;
}

sub _encode {
    my ($self, $tvalue) = @_;
    my $value = 0;
    foreach my $rec (@{ $self->{pairs} }) {
        if (exists $tvalue->{$rec->[0]} and $tvalue->{$rec->[0]}) {
            $value |= $rec->[1];
        }
    }
    return $value;
}

package Data::ParseBinary::ExtractingAdapter;
our @ISA = qw{Data::ParseBinary::Adapter};

sub _init {
    my ($self, $sub_name) = @_;
    $self->{sub_name} = $sub_name;
}

sub _decode {
    my ($self, $value) = @_;
    return $value->{$self->{sub_name}};
}

sub _encode {
    my ($self, $tvalue) = @_;
    return {$self->{sub_name} => $tvalue};
}

package Data::ParseBinary::IndexingAdapter;
our @ISA = qw{Data::ParseBinary::Adapter};

sub _init {
    my ($self, $index) = @_;
    $self->{index} = $index || 0;
}

sub _decode {
    my ($self, $value) = @_;
    return $value->[$self->{index}];
}

sub _encode {
    my ($self, $tvalue) = @_;
    return [ ('') x $self->{index}, $tvalue ];
}

package Data::ParseBinary::JoinAdapter;
our @ISA = qw{Data::ParseBinary::Adapter};

sub _decode {
    my ($self, $value) = @_;
    return join '', @$value;
}

sub _encode {
    my ($self, $tvalue) = @_;
    return [split '', $tvalue];
}

package Data::ParseBinary::ConstAdapter;
our @ISA = qw{Data::ParseBinary::Adapter};

sub _init {
    my ($self, $value) = @_;
    $self->{value} = $value;
}

sub _decode {
    my ($self, $value) = @_;
    if (not $value eq $self->{value}) {
        die "Const Error: expected $self->{value} got $value";
    }
    return $value;
}

sub _encode {
    my ($self, $tvalue) = @_;
    if (not defined $self->_get_name()) {
        # if we don't have a name, then just use the value
        return $self->{value};
    }
    if (defined $tvalue and $tvalue eq $self->{value}) {
        return $self->{value};
    }
    die "Const Error: expected $self->{value} got ". (defined $tvalue ? $tvalue : "undef");
}


package Data::ParseBinary::LengthValueAdapter;
our @ISA = qw{Data::ParseBinary::Adapter};

sub _decode {
    my ($self, $value) = @_;
    return $value->[1];
}

sub _encode {
    my ($self, $tvalue) = @_;
    return [length($tvalue), $tvalue];
}

package Data::ParseBinary::PaddedStringAdapter;
our @ISA = qw{Data::ParseBinary::Adapter};

sub _init {
    my ($self, %params) = @_;
    if (not defined $params{length}) {
        die "PaddedStringAdapter: you must specify length";
    }
    if (defined $params{encoding}) {
        die "PaddedStringAdapter: encoding is not yet implemented";
    }
    $self->{length} = $params{length};
    $self->{encoding} = $params{encoding};
    $self->{padchar} = defined $params{padchar} ? $params{padchar} : "\x00";
    $self->{paddir} = $params{paddir} || "right";
    $self->{trimdir} = $params{trimdir} || "right";
    if (not grep($_ eq $self->{paddir}, qw{right left center})) {
        die "PaddedStringAdapter: paddir should be one of {right left center}";
    }
    if (not grep($_ eq $self->{trimdir}, qw{right left})) {
        die "PaddedStringAdapter: trimdir should be one of {right left}";
    }
}

sub _decode {
    my ($self, $value) = @_;
    my $tvalue;
    if ($self->{encoding}) {
        die "TODO: Should implement different encodings";
    } else {
        $tvalue = $value;
    }
    my $char = $self->{padchar};
    if ($self->{paddir} eq 'right' or $self->{paddir} eq 'center') {
        $tvalue =~ s/$char*\z//;
    } elsif ($self->{paddir} eq 'left' or $self->{paddir} eq 'center') {
        $tvalue =~ s/\A$char*//;
    }
    return $tvalue;
}

sub _encode {
    my ($self, $tvalue) = @_;
    my $value;
    if ($self->{encoding}) {
        die "TODO: Should implement different encodings";
    } else {
        $value = $tvalue;
    }
    if (length($value) < $self->{length}) {
        my $add = $self->{length} - length($value);
        my $char = $self->{padchar};
        if ($self->{paddir} eq 'right') {
            $value .= $char x $add;
        } elsif ($self->{paddir} eq 'left') {
            $value = ($char x $add) . $value;
        } elsif ($self->{paddir} eq 'center') {
            my $add_left = $add / 2;
            my $add_right = $add_left + ($add % 2 == 0 ? 0 : 1);
            $value = ($char x $add_left) . $value . ($char x $add_right);
        }
    }
    if (length($value) > $self->{length}) {
        my $remove = length($value) - $self->{length};
        if ($self->{trimdir} eq 'right') {
            substr($value, $self->{length}, $remove, '');
        } elsif ($self->{trimdir} eq 'left') {
            substr($value, 0, $remove, '');
        }
    }
    return $value;
}

package Data::ParseBinary::StringAdapter;
our @ISA = qw{Data::ParseBinary::Adapter};

sub _init {
    my ($self, $encoding) = @_;
    $self->{encoding} = $encoding;
}

sub _decode {
    my ($self, $value) = @_;
    my $tvalue;
    if ($self->{encoding}) {
        die "TODO: Should implement different encodings";
    } else {
        $tvalue = $value;
    }
    return $tvalue;
}

sub _encode {
    my ($self, $tvalue) = @_;
    my $value;
    if ($self->{encoding}) {
        die "TODO: Should implement different encodings";
    } else {
        $value = $tvalue;
    }
    return $value;
}

package Data::ParseBinary::CStringAdapter;
our @ISA = qw{Data::ParseBinary::StringAdapter};

sub _init {
    my ($self, $terminators, $encoding) = @_;
    $self->SUPER::_init($encoding);
    $self->{regex} = qr/[$terminators]*\z/;
    $self->{terminator} = substr($terminators, 0, 1);
}

sub _decode {
    my ($self, $value) = @_;
    $value =~ s/$self->{regex}//;
    return $value;
}

sub _encode {
    my ($self, $tvalue) = @_;
    return $tvalue . $self->{terminator};
}

package Data::ParseBinary::LamdaValidator;
our @ISA = qw{Data::ParseBinary::Validator};

sub _init {
    my ($self, @params) = @_;
    $self->{coderef} = shift @params;
}

sub _validate {
    my ($self, $value) = @_;
    return $self->{coderef}->($value);
}


1;