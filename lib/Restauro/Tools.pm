#!/usr/bin/env perl

package Restauro::Tools;

use warnings;
use strict;

use base qw/Exporter/;
our @EXPORT = qw/ _uniq_array _is_nucleotide /;

sub _uniq_array {
    my @array = @_;

    my %tmp  = ();
    foreach my $value ( @array ){
        $tmp{$value} = 1;
    }

    return( keys %tmp );
}

sub _is_nucleotide {
    my $seq =  lc(shift);
    $seq    =~ s/>.+\n//g;

    my $threshold = 0.5;
    my $ratio     = 0.0;

    $ratio = $seq =~ tr/atcg/atcg/ / length($seq);
    if ($ratio > $threshold) {
        return 1;
    } else {
        return 0;
    }
}

1;
