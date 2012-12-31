#!/usr/bin/env perl
## :::::::::::::::::: Restauro::External :::::::::::::::::: ##
#
# Restauro-G ver.2 sub module.
# integrating modules which retrieve concrete datasets
# from external databases, resources, web services
#
## ::::::::::::::::::::::::::::::::::::::::::::::::::::::: ##

package Restauro::External;

use strict;
use warnings;

use Restauro::External::Seq;

use base q/Exporter/;
our @EXPORT = qw/ retrieve_dataset parsing_ID_from /;

# retrieve concrete datasets by sub-modules
sub retrieve_dataset {
    my $source = shift;  # base data resources (Tabular generated from restauro)
    my $method = shift; # kind of datasets users want

    # output variable
    my $output = q//;

    if ( $method eq 'AminoSequence' ) {
	$output = Restauro::External::Seq::get_amino_seq( parsing_ID_from($source, 'UniProtKB') );
    } elsif ( $method eq 'NucleotideSequence' ) {
	$output = Restauro::External::Seq::get_nuc_seq( parsing_ID_from($source, 'EMBL') );
    }
    
    return $output;
}

sub parsing_ID_from {
    my $source = shift;
    my $target = shift;

    my @targets = qw//;

    for my $line ( split /\n/, $source ) {
	next if substr($line, 0, 1) eq '#';
	my ($DB, $ID) = split /\s+/, $line;

	if ( $DB eq $target ) {
	    push @targets, $DB.':'.$ID;
	}
    }

    return @targets;
}

1;
