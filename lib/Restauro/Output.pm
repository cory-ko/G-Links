#!/usr/bin/env perl
## ::::::::::::::: Restauro::Output ::::::::::::::: ##
#
# Restauro-G ver.2 sub module.
# subrutines for formatting output data
#
## :::::::::::::::::::::::::::::::::::::::::::::::::::::::: ##

package Restauro::Output;

use warnings;
use strict;

use base qw/Exporter/;
our @EXPORT = qw/ UniProtID_is_notfound convert_xref_to_output convert_BLAT_report_to_output /;

use RDF::Notation3::XML;
use LWP::Simple;
use JSON::XS;
use CGI;

use Restauro::Tools;

# UniProt ID is not found when ID mapping
sub UniProtID_is_notfound {
    return '';
}

# convert xref object to suitable format
sub convert_xref_to_output {
    my $res_xref = shift; # xref object
    my $format   = shift; # output format
    my $db_dir   = shift; # PATH to DB for restauro_g ver2

    # make format
    my (%URL, %URI, %Bio2RDF, %PREDICATE);
    open my $META, '<', $db_dir.'/metadata.tsv';
    for (<$META>) {
	chomp();
	my @line = split(/\t/, $_);
	$PREDICATE{$line[0]} = $line[1] || 'rdfs:seeAlso';
	$Bio2RDF{$line[0]}   = $line[2];
	$URI{$line[0]}       = $line[3];
	$URL{$line[0]}       = $line[4];
    }

    if ( $format eq 'genie' ) {
	return _convert_to_genie_from( $res_xref );
    } elsif ( $format eq 'nt' ) {
	return _convert_to_Notation3_from( $res_xref, \%URL, \%URI, \%Bio2RDF, \%PREDICATE );
    } elsif ( $format eq 'rdf'  ) {
	return _convert_to_RDF_from( $res_xref, \%URL, \%URI, \%Bio2RDF, \%PREDICATE );
    } elsif ( $format eq 'out'  ) {
	return _convert_to_Tabular_from( $res_xref, \%URL );
    } elsif ( $format eq 'json'  ) {
	return _convert_to_JSON_from( $res_xref, \%URL, \%URI, \%Bio2RDF, \%PREDICATE );
    } elsif ( $format eq 'html' ) {
	return _convert_to_html_from( $res_xref, \%URL );
    } else {
	return q//;
    }
}

# Convert BLAT report to Output list
sub convert_BLAT_report_to_output {
    my $blat_report = shift;
    my $format      = shift;

    # output
    my $output = q//;

    # header
    my $header = "# UniProt-ID\tProtein Names\tOrganism\tE-value\tidentity\tlength\tURL";

    # make output table from BLAT report object
    my $table  = q//;
    for my $hit ( @{$blat_report} ) {
	my $UniProt_ID = $hit->{subject};
	my $URL = "http://link.g-language.org/".$UniProt_ID;

	$table .= $UniProt_ID."\t".$hit->{name}."\t".$hit->{os}."\t".$hit->{evalue}."\t".$hit->{identity}."\t".$hit->{length}."\t".$URL."\n";
    }

    if ( lc $format eq 'html' )  {
	# HTML format
	$header =~ s{\t}{</th><th>}g;
	$header =  '<tr><th>'.$header.'</th></tr>';

	my $html_table = q//;
	for my $line ( split /\n/, $table ) {
	    $line =~ s{\t}{</td><td>}g;
	    $line =~ s{(http://link\.g-language\.org/[^\s]+)}{<a href=$1>$1</a>}g;
	    $html_table .= '<tr><td>'.$line."</td></tr>\n";
	}

	$output = _get_HTML_template( [ { header => $header, table => $html_table } ], 3);
    } elsif ( $format eq 'nt' || $format eq 'rdf' ) {

	# Generate triples
	my $triples = q//;

	## Define prefixes
	my @prefixes = (
			'@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .', 
			'@prefix uniprot: <http://purl.uniprot.org/core/> .',
			'@prefix EDAM: <http://edamontology.org/> .',
		       );

	$triples = join("\n", @prefixes)."\n";

	for my $hit ( @{$blat_report} ) {
	    my $UniProt_URL = "http://purl.uniprot.org/uniprot/".$hit->{subject};
	    my $glinks      = "http://link.g-language.org/".$hit->{subject}."/format=".lc($format);

	    $triples .= '<'.$UniProt_URL.">\tEDAM:data_1009\t\"".$hit->{name}    ."\" .\n";
	    $triples .= '<'.$UniProt_URL.">\tEDAM:data_2909\t\"".$hit->{os}      ."\" .\n";
	    $triples .= '<'.$UniProt_URL.">\tEDAM:data_1667\t\"".$hit->{evalue}  ."\" .\n";
	    $triples .= '<'.$UniProt_URL.">\tEDAM:data_1412\t\"".$hit->{identity}."\" .\n";
	    $triples .= '<'.$UniProt_URL.">\tEDAM:data_1249\t\"".$hit->{length}  ."\" .\n";
	    $triples .= '<'.$UniProt_URL.">\tEDAM:data_1883\t<". $glinks         ."> .\n";
	}

	if ( $format eq 'rdf' ) {
	    my $rdf = RDF::Notation3::XML->new();
	    $rdf->parse_string( $triples );
	    $output = $rdf->get_string();
	} else {
	    $output = $triples;
	}
    } else {
	# String (Tabular) format
	$output = $header."\n". $table;
    }

    return $output;
}

sub _convert_to_genie_from {
    my $res_xref  = shift;

    # Header
    my @output = qw//;

    # collect annotatiosn from $res_xref (each UniProt entry)
    for my $query ( keys %{$res_xref} ) {
	for my $UniProt ( keys %{$res_xref->{$query}} ) {
	    my @gene = qw//;

	    for my $entry (  @{$res_xref->{$query}->{$UniProt}->{references}} ) {
		# split to DB name and ID
		my ($db, $id) = split /:/, $entry, 2;
		next unless $id;

		push @gene, join "\t", ($db, $id);
	    }

	    # Add header
	    push @output, "## Database\tID\tURL or Descriptions";

	    for my $entry ( @{$res_xref->{$query}->{$UniProt}->{description}} ) {
		my @splitted_entries = split /:/, $entry;

		if ( $#splitted_entries == 1 ) {
		    # extracted from UniProt raw file directly
		    $splitted_entries[2] = $splitted_entries[1];
		    $splitted_entries[1] = $UniProt;
		    push @output, join "\t", ('# '.$splitted_entries[0], $splitted_entries[1], $splitted_entries[2]);
		} elsif ( $#splitted_entries == 2 ) {
                    # extract WEB RESOURCE from Uniprot raw file directly
                    my $attr = shift @splitted_entries;
                    if ( $attr eq 'WEB RESOURCE' || $attr eq 'DISEASE') {
                        my $description = join ':', @splitted_entries;
                        push @output, '# '.$attr."\t".$UniProt."\t".$description;
                    } else {
                        my $id          = shift @splitted_entries;
                        my $description = join ':', @splitted_entries;
                        push @output, '# '.$attr."\t".$id."\t".$description;
                    }
		} elsif ( $#splitted_entries == 3 ) {
		    my ($attr, $DB, $ID, $description) = @splitted_entries;
		    # [ other descriptions ]
		    # DB:PREFIX:ID:Description -> DB PREFIX:ID Description
		    push @output, join "\t", ('# '.$attr, $DB.':'.$ID, $description);
		} elsif ( $#splitted_entries == 4 ) {
		    my $attr = shift @splitted_entries;
		    my $DB   = shift @splitted_entries;
		    my $ID   = shift @splitted_entries;
		    my $desc = join ':', @splitted_entries;
		    push @output, join "\t", ('# '.$attr, $DB.':'.$ID, $desc);
		} else {
		    # extracted from other source
		    my ($DB, $ID, $description) = @splitted_entries;
		    push @output, join "\t", ('# '.$DB, $ID, $description);
		}
	    }

	    push @output, @gene;
	    push @output, "//";
	}
    }

    # uniq and join
    @output = split m{//\n}, join "\n", @output;

    return join "//\n", @output;
}


# Convert xref object to Notation3 format
sub _convert_to_Notation3_from {
    my $res_xref  = shift;
    my %URL       = %{+shift};
    my %URI       = %{+shift};
    my %Bio2RDF   = %{+shift};
    my %PREDICATE = %{+shift};

    # Generate triples
    my $triples = q//;

    ## Define prefixes
    my @prefixes = (
		    '@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .', 
		    '@prefix uniprot: <http://purl.uniprot.org/core/> .',
		    '@prefix EDAM: <http://edamontology.org/> .',
		 );

    $triples = join("\n", @prefixes)."\n";

    for my $query ( keys %{$res_xref} ) {
	for my $UniProt ( keys %{$res_xref->{$query}} ) {
	    my @xref = @{$res_xref->{$query}->{$UniProt}->{references}};
#	    my @desc = @{$res_xref->{$query}->{$UniProt}->{description}};

	    my @list = qw//;	# object list
	    for my $xref (@xref) {
		my ($db, $id) = split(/:/, $xref, 2);
		next if ! $db || ! $id;

		if (substr($id, -1) eq '.') {
		    substr($id, -1) = '';
		}

		if ( $id =~ />|</ ) {
		    $id = CGI::escape($id);
		}

		if ($URI{$db}) {
		    my $uri = $URI{$db};
		    $uri =~ s/<id>/$id/;
		    push(@list, $PREDICATE{$db}."\t<".$uri."> .\n");
		} elsif ( $Bio2RDF{$db} ) {
		    my $uri = $Bio2RDF{$db};
		    $uri =~ s/<id>/$id/;
		    push(@list, $PREDICATE{$db}."\t<".$uri."> .\n");
		}
	    }

	    my $UniProt_URI = $URI{'UniProtKB'};
	    $UniProt_URI =~ s/<id>/$UniProt/;
	    for ( _uniq_array(@list) ) {
		$triples .= '<'.$UniProt_URI.">\t".$_;
	    }
	}
    }

    return $triples;
}


# Convert xref object to RDF format
sub _convert_to_RDF_from {
    my $rdf = RDF::Notation3::XML->new();
    $rdf->parse_string( _convert_to_Notation3_from( @_ ) );
    return $rdf->get_string();
}


# Convert xref object to Tabular format
sub _convert_to_Tabular_from {
    my $res_xref  = shift;
    my %URL       = %{+shift};

    # Header
    my $output = q//;

    # collect annotatiosn from $res_xref (each UniProt entry)
    for my $query ( keys %{$res_xref} ) {

	for my $UniProt ( keys %{$res_xref->{$query}} ) {
	    # push all annotations to @references, uniq, and join
	    my @references   = qw//;
	    my @descriptions = qw//;

	    my @xref = @{$res_xref->{$query}->{$UniProt}->{references}};
	    my @desc = @{$res_xref->{$query}->{$UniProt}->{description}};

	    for my $entry (@xref) {
		# split to DB name and ID
		my ($db, $id) = split /:/, $entry, 2;
		next unless $id;

		# remove version number from $id
		if (substr($id, -1) eq '.') {
		    substr($id, -1) = '';
		}

		# remove unavailable ID
		next if $id eq '-';

		# generate URL from each IDs
		my $uri = $URL{$db};
		if ($uri) {
		    $uri =~ s/<id>/$id/;
		    push @references, $db."\t".$id."\t".$uri;
		}
	    }

	    for my $entry ( @desc ) {
		my @splitted_entries = split /:/, $entry;

		if ( $#splitted_entries < 1 ) {
		    next;
		} elsif ( $#splitted_entries == 1 ) {
		    # extracted from UniProt raw file directly
		    my ($attr, $description) = @splitted_entries;
		    push @descriptions, '# '.$attr."\t".$UniProt."\t".$description;
		} elsif ( $#splitted_entries == 2 ) {
		    # extract WEB RESOURCE and DISEASE from Uniprot raw file directly
		    my $attr = shift @splitted_entries;
		    if ( $attr eq 'WEB RESOURCE' || $attr eq 'DISEASE') {
			my $description = join ':', @splitted_entries;
			push @descriptions, '# '.$attr."\t".$UniProt."\t".$description;
		    } else {
			my $id          = shift @splitted_entries;
			my $description = join ':', @splitted_entries;
			push @descriptions, '# '.$attr."\t".$id."\t".$description;
		    }
		} elsif ( $#splitted_entries == 3 ) {
		    my ($attr, $DB, $ID, $description) = @splitted_entries;
		    die $attr unless $description;
		    if ( $attr eq 'Gene3D' ) {
			# [ this description is related to Gene3D ]
			# Gene3D:3.40.366.10:G3DSA:3.40.366.10 -> Gene3D 3.40.366.10 G3DSA:3.40.366.10 
			push @descriptions, '# '.$attr."\t".$DB."\t".$ID.':'.$description;
		    } else {
			# [ other descriptions ]
			# DB:PREFIX:ID:Description -> DB PREFIX:ID Description
			push @descriptions, '# '.$attr."\t".$DB.':'.$ID."\t".$description;
		    }
		} elsif ( $#splitted_entries == 4 ) {
		    my $attr = shift @splitted_entries;
		    my $DB   = shift @splitted_entries;
		    my $ID   = shift @splitted_entries;
		    my $desc = join ':', @splitted_entries;
		    push @descriptions, '# '.$attr."\t".$DB.':'.$ID."\t".$desc;
		} else {
		    # extracted from other source
		    my ($DB, $ID, $description) = @splitted_entries;
		    next unless $DB;
		    next unless $ID;
		    next unless $description;
		    push @descriptions, '# '.$DB."\t".$ID."\t".$description;
		}
	    }

	    # Add header
	    $output .= "## Database\tID\tURL or Descriptions\n";

	    if ( $#descriptions > -1 ) {
		$output .= join("\n", sort { $a cmp $b } @descriptions)."\n";
	    }

	    if ( $#references > -1 ) {
		$output .= join("\n", sort { $a cmp $b } @references)."\n";
	    }

	}

    }

    return $output;
}

# Convert xref object to RDF format
sub _convert_to_JSON_from {
    my $res_xref  = shift;
    my %URL       = %{+shift};
    my %URI       = %{+shift};
    my %Bio2RDF   = %{+shift};
    my %PREDICATE = %{+shift};

    # Header
    my @json = qw//;

    # collect annotatiosn from $res_xref (each UniProt entry)
    for my $query ( keys %{$res_xref} ) {
	# push all annotations to @references, uniq, and join
	
	my $refs4each_query;
	for my $UniProt ( keys %{$res_xref->{$query}} ) {
	    my @references   = qw//;

	    my @xref = @{$res_xref->{$query}->{$UniProt}->{references}};
#	    my @desc = @{$res_xref->{$query}->{$UniProt}->{description}};

	    for my $entry (@xref) {
		# split to DB name and ID
		my ($db, $id) = split /:/, $entry, 2;
		next unless $id;

		# remove version number from $id
		if (substr($id, -1) eq '.') {
		    substr($id, -1) = '';
		}

		# remove unavailable ID
		next if $id eq '-';

		# generate URL from each IDs
		my $uri = $URL{$db};
		if ($uri) {
		    $uri =~ s/<id>/$id/;
		    push @references, $db."\t".$id."\t".$uri;
		}
	    }

	    for my $line ( @references ) {
		my ($category, $ID, $desc) = split /\t/, $line;
		push @{$refs4each_query->{$UniProt}} , {
							'Database'    => $category,
							'ID'          => $ID,
							'URL'         => $desc,
						       };
	    }
	}

	push @json, { $query => $refs4each_query };
    }

    # output as join
    return encode_json \@json;
}

# make html page from tabular output
sub _convert_to_html_from {
    my @tables = qw//; # entries for HTML table
    my @images = qw//; # URLs for imageflow

    for my $entry ( split m{\n##\s}, _convert_to_Tabular_from( @_ ) ) {
	my @lines  = split /\n/, $entry;

	my $header = shift @lines;
	$header =~ s{^(?:##\s)*(.+)\t(.+)\t(.+)}{      <tr class="header"><th>$1</th><th>$2</th><th>$3</th></tr>};

	my $output = q//;
	for my $line ( @lines ) {
	    my @entry = split /\t/, $line;

	    if ( $entry[0] eq '# WEB RESOURCE' ) {
		$entry[2] =~ s{^Name=(.+)URL=\"(https?://[^\s]+)\"\;}{<a href=$2>$1</a>};
	    } elsif ( $entry[0] eq '# KEGG_Pathway' ) {
		push @images, '<img src="http://rest.kegg.jp/get/'.$entry[1].'/image" longdesc="http://www.genome.jp/kegg-bin/show_pathway?'.$entry[1].'" width="100" height="100" alt="'.$entry[2].'" />';
	    } elsif ( $entry[0] eq 'PDB' ) {
		# RCSB PDB (license free)
		$entry[2] =~ s{(https?://[^\s]+)}{<a href=$1>$1</a>}g;

		push @images, '<img src="http://www.rcsb.org/pdb/images/'.$entry[1].'_asym_r_250.jpg" longdesc="http://www.ebi.ac.uk/pdbe-srv/view/entry/'.$entry[1].'" width="100" height="100" alt="PDB:'.$entry[1].'" />';
	    } elsif ( $entry[0] eq 'STRING' ) {
		# STRING Protein-Protein Interaction network

		my ($image_url) = get('http://string-db.org/newstring_cgi/show_network_section.pl?identifier='.$entry[1]) =~ m{(http://string-db\.org/newstring_userdata/net_image_.+?\.png)};
		push @images, '<img src="'.$image_url.'" longdesc="http://string-db.org/newstring_cgi/show_network_section.pl?identifier='.$entry[1].'" width="100" height="100" alt="STRING:'.$entry[1].'" />' if $image_url;

		$entry[2] =~ s{(https?://[^\s]+)}{<a href=$1>$1</a>}g;
	    } elsif ( $entry[0] eq 'Jabion' ) {
		# Jabion

		my ($image_url) = 'http://www.bioportal.jp/genome/cgi-bin/graph.cgi%3Forg=hs%26id='.$entry[1];
		push @images, '<img src="'.$image_url.'" longdesc="http://www.bioportal.jp/genome/cgi-bin/gene_homolog.cgi?org=hs&id='.$entry[1].'" width="100" height="100" alt="Jabion:'.$entry[1].'" />' if $image_url;

		$entry[2] =~ s{(https?://[^\s]+)}{<a href=$1>$1</a>}g;
	    } elsif ( $entry[0] eq 'COXPRESdb' ) {
		for my $url_base ( qw{ http://coxpresdb.jp/data/fig_LCNloc.2010-09-14.kegg/  http://coxpresdb.jp/data/fig_tissue.Hsa.070630/s_ } ) {
		    my $img_url = $url_base.$entry[1].'.png';
		    my $cmd = 'curl -o /dev/null -s -w "%{http_code}" -I '.$img_url;
		    if ( `$cmd` == 200 ) {
			push @images, '<img src="'.$img_url.'" longdesc="'.$entry[2].'" width="100" height="100" alt="COXPRESdb:'.$entry[1].'" />';
		    }
		}
		$entry[2] =~ s{(https?://[^\s]+)}{<a href=$1>$1</a>}g;
	    } else {
		$entry[2] =~ s{(https?://[^\s]+)}{<a href=$1>$1</a>}g;
	    }
	    $output .= '      <tr>   <td>'.$entry[0].'</td><td>'.$entry[1].'</td><td>'.$entry[2]."</td></tr>\n";
	}

	push @tables, { header => $header, table => $output };
    }

    return _get_HTML_template(\@tables, 0, _make_image_flow(@images) );
}

sub _get_HTML_template {
    my @tables = @{+shift};
    my $sorted = shift || 0;
    my $flow   = shift || "\n";


    my $table = q//;
    for ( @tables ) {
	my $header = $_->{header};
	my $body   = $_->{table};

	$table .= <<EOF;

<table id="table" class="tablesorter">
    <thead>
$header
    </thead>
    <tbody>
$body
    </tbody>
  </table>
EOF
    }

    return<<HTML;
<!DOCTYPE html>
<html lang=en>
  <meta charset=utf-8>
  <meta name=viewport content="initial-scale=1, minimum-scale=1, width=device-width">
  <script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.7.2/jquery.min.js"></script>
  <script type="text/javascript" src="http://link.g-language.org/js/jquery.tablesorter.js"></script>
  <link rel="stylesheet" href="http://link.g-language.org/style/style.css" type="text/css" media="print, projection, screen" />
  <script> \$(document).ready(function() { \$("table").tablesorter( {sortList: [[$sorted,0]], widgets: ['zebra']} ); } ); </script>
$flow
$table
HTML

}

# Make ImageFlow table
sub _make_image_flow {
    if ( $#_ == -1 ) {
	return q//;
    } else {
	my $images = join "\n", @_;

	return <<FLOW;
  <style> tbody {height: 500px; overflow-y: auto; } </style>

  <link rel="stylesheet"         href="http://link.g-language.org/style/imageflow.css" type="text/css" />
  <script type="text/javascript" src="http://link.g-language.org/js/imageflow.js"></script>

  <div id="myImageFlow" class="imageflow">
$images
  </div>
FLOW

    }
}

1;
