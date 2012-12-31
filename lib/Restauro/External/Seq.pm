#!/usr/bin/env perl
## :::::::::::::::: Restauro::External::Seq ::::::::::::::: ##
#
# Restauro-G ver.2 sub module.
# This module has methods related to sequence.
# 
## :::::::::::::::::::::::::::::::::::::::::::::::::::::::: ##

package Restauro::External::Seq;

use strict;
use warnings;

use LWP::Simple;

# retrieve Amino acid sequence(s) via TogoWS
sub get_amino_seq {
    # remove prefix
    my @ID = map { $_ =~ m{^UniProtKB:(.+)$}; $1 } @_;

    # access to TogoWS
    return get('http://togows.dbcls.jp/entry/uniprot/'.join(',',@ID).'.fasta');
}

# retrieve Nucleotide sequence(s) via TogoWS
sub get_nuc_seq {
    # remove prefix
    my @ID = map { $_ =~ m{^EMBL:(.+)$}; $1 } @_;

    # access to TogoWS
    return get('http://togows.dbcls.jp/entry/embl/'.join(',',@ID).'.fasta');
}

1;
