#!/usr/bin/env perl

package Restauro::Blat;

use warnings;
use strict;

use base qw/Exporter/;
our @EXPORT = qw/ blat4sequence parse_blat_report /;

use Storable qw/ retrieve /;
use Restauro::Tools;

sub blat4sequence {
    my $fasta     = shift;
    my $base_info = shift;

    my $evalue   = $base_info->{'evalue'};
    my $identity = $base_info->{'identity'};

    my @ID = qw//;
    my ($head, $sequence) = ('QUERY', '');
    if ( $fasta =~ />/ ) {
	($sequence) = $fasta =~ m{ ^ [>] [^\n]+ \n (.+) $ }msx;
    } else {
	$sequence   = $fasta;
    }

    my $query_file = $base_info->{'tmp_path'}.'/query.fasta';
    my $query_length = { 'QUERY' => length($sequence) };
    my $database  = $base_info->{'DB_sprot'}->[0];
    my $info_file = $base_info->{'info_sprot'};
    my $db_length = retrieve $info_file->[0];
    my $output    = $base_info->{'tmp_path'}.'/sprot.blat';

    if ( _is_nucleotide($sequence) ) {
        $query_length->{"QUERY"} = sprintf("%d", $query_length->{'QUERY'} / 3);

        open  QUERY, '>', $query_file.'.tmp';
        print QUERY  ">QUERY\n",$sequence;
        close QUERY;

	system('/usr/local/bin/transeq '.$query_file.'.tmp -frame 6 -auto -outseq '.$query_file.'.tmp2');

	open  QUERY, '>', $query_file;
	open  TMP,   '<', $query_file.'.tmp2';
	while (<TMP>) {
	    chomp();
	    if ( $_ =~ m/^\>QUERY_[1-6]/ ) {
		print QUERY ">QUERY\n";
	    } else {
		print QUERY $_,"\n";
	    }
	}
	close TMP;
	close QUERY;
    } else {
        open  QUERY, '>', $query_file;
        print QUERY  ">QUERY\n",$sequence;
        close QUERY;
    }

    # execute BLAT search against Swiss-Prot DB
    system("/usr/local/bin/blat $database $query_file $output -prot -out=blast8 -minScore=100 > /dev/null");

    my $sprot_result = parse_blat_report($output, $query_length, $db_length, $evalue, $identity);

    if ( $sprot_result->{'QUERY'} ) {
        push( @ID, sort {$a->{evalue} <=> $b->{evalue}} @{$sprot_result->{'QUERY'}} );
    }

    return @ID;
}

sub parse_blat_report {
    my $blat_out     = shift;
    my %query_length = %{+shift};
    my $db_length    = shift;
    my $th_evalue    = shift;
    my $th_identity  = shift;

    if ($th_identity && $th_identity <= 1.0) {
        $th_identity = $th_identity * 100;
    }

    my $ret_obj;

    open BLAT, '<', $blat_out;
    while (<BLAT>) {
        chomp();

        my $tmp_obj;

        my ($query, $subject, $identity, undef, undef, undef, undef, undef, undef, undef, $evalue, $score) = split(/\t/, $_);
        (undef, $subject, undef) = split(/\|/, $subject);

        $tmp_obj->{subject}  = $subject;
        $tmp_obj->{evalue}   = $evalue;
        $tmp_obj->{identity} = $identity;
	$tmp_obj->{length}   = $db_length->{$subject};

        if ( $th_identity <= $identity && $evalue <= $th_evalue ) {
            push( @{$ret_obj->{$query}} , $tmp_obj );
        }
    }
    close BLAT;

    return $ret_obj;
}

1;
