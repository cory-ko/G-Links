#!/usr/bin/env perl
#
# Output parameter and metadata related to Restauro-G version 2
#

use strict;
use warnings;

# import CGI modules
use CGI;
use CGI::Carp qw(fatalsToBrowser);

# make CGI object
my $q = CGI->new();

# Output parameter and metadata related to Restauro-G version 2
if ( $q->param('filter') ) {    # show filter info
    my $filter_def = "db/filter.txt";

    open my $fh, "<", $filter_def or die $!;
    my %filter = map { ( $_->[0] => [split(/,/, $_->[1])] ) } map { [split(/\s/, $_)] } <$fh>;
    close $fh;

    print $q->header('text/plain');
    print "Filter Name\tCandidate Databases\n";
    print "###########\t###################\n";

    for my $filter ( sort keys %filter ) {
	my $DBs = $filter{$filter};
	print $filter."\t".join(",", @{$DBs})."\n";
    }
} elsif ( $q->param('output') ) {    # show output DBs
    my $ontology_def = "db/metadata.tsv";

    open my $fh, "<", $ontology_def or die $!;
    my %ontology = map { ( $_->[0] => $_->[1] ) } map { [split(/\s/, $_)] } <$fh>;
    close $fh;

    print $q->header('text/plain');
    print "Database\n";
    print "########\n";
    for my $DB ( sort keys %ontology ) {
	print $DB."\n";
    }
=pod
    print "Database\tOntology\n";
    print "########\t###################\n";
    for my $DB ( sort keys %ontology ) {
	my $ontology = $ontology{$DB} || "rdfs:seeAlso";
	print $DB."\t".$ontology."\n";
    }
=cut
} elsif ( $q->param('input') ) {    # show input DBs
    my $i_list = "db/ilist.tsv";

    open my $fh, "<", $i_list;
    my %ilist = map { ( $_->[0] => $_->[1] ) } map { [split(/\s/, $_)] } <$fh>;
    close $fh;

    print $q->header('text/plain');
    print "Database\tExample ID\n";
    print "########\t##########\n";
    for my $DB ( sort keys %ilist ) {
	print $DB."\t".$ilist{$DB}."\n";
    }
} else {
    # redirect to wiki document page
    print $q->redirect("http://www.g-language.org/wiki/restauro");
}

