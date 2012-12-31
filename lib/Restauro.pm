#!/usr/bin/env perl
#
# This package is part of Restauro-G version 2
# Main package including 'annotator' method
#

package Restauro;

use warnings;
use strict;

use base q/Exporter/;
our @EXPORT = qw/ annotator /;

# import other classes about Restauro-G version 2
use Restauro::Output;
use Restauro::Tools;
use Restauro::Blat;
use Restauro::Init;

# import CPAN modules
use Storable qw/ retrieve /;
use LWP::Simple;
use File::Path;
use DBI;

# Main function for Restauro-G version 2
# input user's query to this subrutine
# Usage: annotator( "GENE ID or SEQ", "FORMAT", "FILTER", "E-VALUE", "IDENTITY", "DIRECT")
### E-VALUE, IDENTITY and DIRECT are able to work only when query is amino/nuc sequence
sub annotator {
    my $query=    shift;
    my $format=   shift || 'out';
    my @filter=   @{+shift};
    my @extract=  @{+shift};
    my $evalue=   shift;
    my $identity= shift;
    my $direct=   shift;
    my $no_cache= shift || undef;

    # initializing environments
    my $base_info = init_info();
    my $tmp_dir   = $base_info->{'tmp_path'};
    my $jobid     = $base_info->{'jobid'};
    my $db_dir    = $base_info->{'db_path'};

    # make interface to access MySQL DB
    my $dbh = DBI->connect( 'dbi:mysql:glinks:127.0.0.1', 'guest', '' ) || die $DBI::errstr;

    my %UniProtID2query = qw//;
    my @all_UniProtIDs  = qw//;

    my @genes = qw//;
    if ( $query =~ /,/ ) {
	@genes = split /\s*,\s*/, $query;
    } else {
	my $taxid = q//;

	# taxonomy search
	my $fields = q//;
	if (      $query =~ /^\d+$/ ) {
	    $fields = 'taxid';
	} else {
	    $fields = 'nc';
	}

	my $sqlquery = 'select * from taxonomy where '.$fields.' = \''.$query.'\'';

	my $sth = $dbh->prepare($sqlquery);
	$sth->execute || die $sth->errstr;

	my $result = q//;
	while ( my $ref = $sth->fetchrow_arrayref() ) {
	    $taxid = $ref->[1];
	    @all_UniProtIDs = split /,/, $ref->[3];
	}

	if ( $#all_UniProtIDs > -1 ) {
	    if ( $format eq 'genie' ) {
		if (!$no_cache && -e './db/genie/'.$taxid.'.nstore' ) {
		    my @genie = @{ retrieve './db/genie/'.$taxid.'.nstore' };
		    if ( $#filter > -1 ) {
			for my $filter ( @filter ) {
			    next unless $filter;
			    if ( $filter =~ /^(.*?):(.+)$/ ) {
				@genie = grep { /$1\t[^\n]*$2/i } @genie;
			    } else {
				@genie = grep { /$filter\t/ } @genie;
			    }
			}
		    }
		    if ( $#extract > -1 ) {
			my $extracter = join('\t|', @extract)."\t|UniProtKB\t|##";

			my @extracted = qw//;
			for my $genie (@genie) {
			    push @extracted, join("\n", grep m{$extracter}, split /\n/, $genie)."\n";
			}
			@genie = @extracted;
		    }
		    return join "//\n", @genie;
		}
	    }
	    map { push @{$UniProtID2query{$_}}, $query; } @all_UniProtIDs;
	} else {
	    push @genes, $query;
	}
    }


    for my $gene ( _uniq_array(@genes) ) {
	# [ $query is not organism name ( $#genes == -1 ) ]
	my $sequence   = q//;
	my @UniProt_ID = qw//;

	# check $gene is UniProt ID or not
	my @xref_num;
	if ( $gene =~ /.+:(.+)/ ) {
	    # [$gene is USA] => remove prefix
	    # try to retrieve UniProt annotation from uniprot table
	    @xref_num = _uniprot2annotation($dbh, $1);
	} else {
	    # [$gene is raw UniProt ID]
	    # try to retrieve UniProt annotation from uniprot table
	    @xref_num = _uniprot2annotation($dbh, $gene);
	}

	# ID mapping
	# if $#xref_num != -1 (extract UniProt data directly), $gene is UniProt ID
	if ($#xref_num != -1) {
	    # [$gene is UniProt ID]
	    push @UniProt_ID, $gene;
	} else {
	    # [$gene is other database ID, sequence or not acceptable data]
	    unless ( length($gene) > 30 ) { # query is any Gene 'ID'
		# try convert $gene to UniProt ID with our IDmapping database
		my @tmp_id = _gene2UniProt($dbh, $gene);

		# $gene is UniProtKB-AC without prefix (take priority over other DB (i.e. HSSP))
		if ( $#tmp_id != -1 && $gene !~ /:/ ) {
		    my ($UniProt_AC) = grep { $_->{db} eq 'UniProtKB-AC' } @tmp_id;

		    if ( $UniProt_AC && $UniProt_AC->{ac} eq $gene ) {
			@tmp_id = ( $UniProt_AC );
		    }
		}

		# delete version number from $gene (when @tmp_id has no entry)
		if ( $#tmp_id == -1 && $gene =~ m{^(.+)\.\d+} ) {
		    @tmp_id = _gene2UniProt($dbh, $1);
		}

		# if no UniProt ID and $gene has prefix as USA format
		if ( $#tmp_id == -1 && $gene =~ /(.+):(.+)/ ) {
		    my ($db, $id) = ($1, $2);

		    # check whether $gene is UniProt ID and UniProt AC
		    if ( lc $db eq 'uniprot' || lc $db =~ /uniprotkb/ ) {
			if ( $id =~ /_/ ) {
			    $db = 'UniProtKB-ID';
			} else {
			    $db = 'UniProtKB-AC';
			}
		    }

		    @tmp_id = _gene2UniProt($dbh, $gene);
		    # re-try to convert
		    @tmp_id = grep { lc $_->{db} eq lc $db } _gene2UniProt($dbh, $id);

		    # re-try to convert without version number
		    if ( $#tmp_id == -1 && $id =~ m{^(.+)\.\d+} ) {
			# [if $id has version number (i.e. NC_000913.1)]
			@tmp_id = grep { lc $_->{db} eq lc $db } _gene2UniProt($dbh, $id);
		    }
		}

		# if not able to convert yet, Restauro-G try to get sequence from TogoWS with G-language
		if ( $#tmp_id == -1 ) {
		    # 'query' (maybe ID) is able to be solved by Restauro-G id mapping
		    # replace installed G-language to REST service (avoid creation 'data/' and 'graph/')
		    $sequence = get('http://rest.g-language.org/togoWS/'.$gene.'/-format/fasta');
		} else {
		    # convert UniProtKB-AC to UniProtKB-ID and uniq
		    @tmp_id = _uniq_array( map { $_->{ac} } @tmp_id );
		    for my $entry ( _uniprotAC2ID($dbh, @tmp_id) ) {
			push( @UniProt_ID, $entry->{id} );
		    }
		}
	    } else {
		# query is 'sequence'
		$sequence = $gene;
	    }
	}

	# BLAT search
	if ($sequence) {
	    # [$gene is sequence data]

	    # set-up options for BLAT search
	    if ($evalue) {
		$base_info->{'evalue'} = $evalue;
	    }
	    if ($identity) {
		$base_info->{'identity'} = $identity;
	    }

	    # execute BLAT search
	    my @blat_report = sort { $a->{evalue} <=> $b->{evalue} } blat4sequence($sequence, $base_info);

	    # I'm feeling lucky!
	    if ( $direct ) {
		# [-direct option is given]


		# convert UniProt AC to ID
		push @UniProt_ID, map { $_->{id} } _uniprotAC2ID($dbh, $blat_report[0]->{subject});
	    } else {
		my ($blat_report, %AC2ID, %ID2Name, %ID2OS);

		# %AC2ID is converter which convert UniProt AC to ID
		for ( _uniprotAC2ID($dbh, map { $_->{subject} } @blat_report) ) {
		    $AC2ID{$_->{ac}} = $_->{id};
		}

		# convert UniProt AC to Protein name and organism
		for ( _uniprot2annotation($dbh, values %AC2ID) ) {
		    # extract Protein name
		    my ($name) = $_->{de} =~ m{RecName:(.+)};
		    if ( $name =~ /<BR>/ ) {
			($name) = split /<BR>/, $name;
		    }
		    $ID2Name{$_->{id}} = $name;
		    $ID2OS{  $_->{id}} = $_->{os};
		}

		# update BLAT report object
		for (@blat_report) {
		    my $UniProt_ID = $AC2ID{ $_->{subject} };

		    my $report = {
				  'subject'  => $UniProt_ID,
				  'evalue'   => $_->{evalue},
				  'name'     => $ID2Name{$UniProt_ID},
				  'identity' => $_->{identity},
				  'os'       => $ID2OS{$UniProt_ID},
				  'length'   => $_->{length},
				 };

		    push @{$blat_report}, $report;
		}

		# convert BLAT report to output table
		return convert_BLAT_report_to_output( $blat_report, $format );
	    }
	}

	push @all_UniProtIDs, @UniProt_ID;
	for ( @UniProt_ID ) {
	    push @{$UniProtID2query{$_}}, $gene;
	}
    }

    # UniProt ID is Not Found
    if ($#all_UniProtIDs == -1) {
	return UniProtID_is_notfound();
    }

    # structured object which memories all annotation extracted from Restauro-G DB
    # @{$res_xref->{query}->{UniProt_ID}}
    my $res_xref;

    my %known_UniProt;
    # extracting UniProt annotation from UniProt Flat file with _uniprot2annotation method

    my ($UniProt_ID, $ac, $cc, $de, $os, $dr, $rx, $ex);
    my $uniprot_sth =
	$dbh->prepare( 'select * from uniprot where id in ('.join(',', map{'"'.$_ .'"'} @all_UniProtIDs).')' );
    $uniprot_sth->execute || die $uniprot_sth->errstr;
    $uniprot_sth->bind_columns( undef, (\$UniProt_ID, \$ac, \$cc, \$de, \$os, \$dr, undef, undef, \$rx, \$ex) );

    MAIN: while( $uniprot_sth->fetchrow_arrayref() ){
	# $UniProt_Annotation => ( id ac cc de os dr gn pe rx ex )

	# caching annotations by UniProt ID
	if ( $known_UniProt{$UniProt_ID} ) {
	    next;
	} else {
	    $known_UniProt{$UniProt_ID}++;
	}

	my @xref        = ( 'UniProtKB:'.$UniProt_ID );
	my @description = qw//;

	# AC Record
	# my ($uniprot_ac) = split /;\s*/, $ac;#
	# push @xref, 'UniProtKB-AC:'.$uniprot_ac;#
	push @xref, 'UniProtKB-AC:'.$ac;

	# CC Record
	if ( $cc ) {
	    push @description, split /<BR>/, $cc;
	}

	# DE Record
	if ($de) {
	    push @description, split /<BR>/, $de;
	}

	# OS Record
	if ( $os && $format ne 'genie' ) {
	    push @description, $os;
	}

	# DR Record
	if ( $dr ) {
	    for my $xref ( split /<BR>/, $dr ) {
		my ($ID_data, $desc_data) = split /;;/, $xref;
		push @xref, $ID_data;
		push @description, $ID_data.':'.$desc_data if $desc_data && $format ne 'genie';
	    }
	}

	# GN Record [6]
	# PE Record [7]

	# RX Record
	if ( $rx ) {
	    for my $xref ( split /<BR>|;\s*/, $rx ) {
		next unless $xref;
		$xref =~ s/=/:/;
		push @xref, $xref;
	    }
	}

	if ( $ex ) {
	    for my $xref ( split /<BR>/, $ex ) {
		next unless $xref;

		# [DB:ID;;description] or [DB:ID]
		my ($ref, $desc) = split /;;/, $xref;
		if ($desc) {
		    push @description, $ref.':'.$desc;
		}
		push @xref, $ref;
	    }
	}

	# filtering all data
	if ( $#filter > -1 ) {
	    for my $filter ( @filter ) {
		next unless $filter;
		if ( $filter =~ /^(.*?):(.+)$/ ) {
		    unless ( grep { /$1:.*$2/i } @xref ) {
			unless ( grep { /$1:.*$2/i } @description ) {
			    next MAIN;
			}
		    }
		} else {
		    unless ( grep { /$filter:/ } @xref ) {
			unless ( grep { /$filter:/ } @description ) {
			    next MAIN;
			}
		    }
		}
	    }
	}

	# extracting specified info
	if ( $#extract > -1 ) {
	    my $extracter = join(':|', @extract).":|UniProtKB:";

	    @xref        = grep m{$extracter}, @xref;
	    @description = grep m{$extracter}, @description;
	}

	# push all annotation data into $res_xref object
	for ( @{$UniProtID2query{$UniProt_ID}} ) {
	    push @{$res_xref->{$_}->{$UniProt_ID}->{description}},  @description;

	    push @xref, 'G-Links:'.$_ if $#extract == -1 || grep /G-Links/, @extract;
	    push @{$res_xref->{$_}->{$UniProt_ID}->{references}},   @xref;
	}

    }

    # close connection to mysql server
    $dbh->disconnect();

    # delete exceeds metadata (i.e. query and raw result by BLAT search)
    if ( -d $tmp_dir ) {
	rmtree($tmp_dir);
    }

    # Output (String)
    return convert_xref_to_output($res_xref, $format, $db_dir);
}


sub _gene2UniProt {
    my $dbh = shift;

    my $sqlquery = 'select * from idmapping where id in ('. join(',', map{'"'.$_.'"'} @_) .')';
    my $sth = $dbh->prepare($sqlquery);
    $sth->execute || die $sth->errstr;

    my @result;
    while( my $ref = $sth->fetchrow_arrayref() ){
        push @result, { 'ac' => $ref->[1], 'db' => $ref->[2], 'id' => $ref->[3] };
    }

    return @result;
}

sub _uniprotAC2ID {
    my $dbh = shift;

    my $sqlquery = 'select * from idmapping where ac in (' . join(',', map{'"'. $_ . '"'} @_) . ')';
    my $sth = $dbh->prepare($sqlquery);
    $sth->execute || die $sth->errstr;

    my @result;
    while( my $ref = $sth->fetchrow_arrayref() ){
        push @result, { 'ac' => $ref->[1], 'id' => $ref->[3] } if $ref->[2] eq 'UniProtKB-ID';
    }

    return @result;
}

sub _uniprot2annotation {
    my $dbh = shift;

    my $sqlquery = 'select * from uniprot where id in (' . join(',', map{'"'. $_ . '"'} @_) . ')';
    my $sth = $dbh->prepare($sqlquery);
    $sth->execute || die $sth->errstr;

    my @result;
#   my @fields = qw/ id ac cc de os dr gn pe rx /;
    while( my $ref = $sth->fetchrow_arrayref() ){
       push @result, {
                      id => $ref->[0],
                      ac => $ref->[1],
                      cc => $ref->[2],
                      de => $ref->[3],
                      os => $ref->[4],
                      dr => $ref->[5],
#                     gn => $ref->[6],
#                     pe => $ref->[7],
                      rx => $ref->[8],
                     };
   }

    return @result;
}

1;
