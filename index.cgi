#!/usr/bin/env perl
use warnings;
use strict;

# import CGI modules
use CGI::Carp qw(fatalsToBrowser);
use CGI;

# import core modules
use lib qw( ./lib/ );
use Restauro;

# import accessor to external services
use Restauro::External;

# version information
our $VERSION = 1.0.0;

# make CGI object and check error
my  $q = CGI->new();
die $q->cgi_error if $q->cgi_error;

# set up charset
$q->charset('utf-8');
binmode STDOUT, ':utf8';

# given Gene ID or sequence data as query
if ( my $arg = $q->param('query') ) {
    # clearning $arg (delete excess \s and \t)
    $arg =~ s/\s//g;
    $arg =~ s/\t//g;

    # separate Gene ID (or sequence) and parameters
    my ($id, $param) = split /\//, $arg, 2;

    # set-up parameters given by users
    my ($format, $evalue, $identity, $direct, $category) = ('', '', 0, 0, 0, '');
    my @filter  = qw//;
    my @extract = qw//;
    if ($param) {
        for ( split(/\//, $param) ) {
            if ( $_ =~ m{([^=]+)=([^=]+)} ) {
	        my ($paramName, $paramValue) = ($1, $2);
	        if (      lc($paramName) eq 'format'   && length($paramValue) ) {
		    $format   = lc($paramValue);
	        } elsif ( lc($paramName) eq 'filter'   && length($paramValue) ) {
		    if ( $paramValue =~ /\|/ ) {
			push @filter, split /\|/, $paramValue;
		    } else {
			push @filter, $paramValue;
		    }
	        } elsif ( lc($paramName) eq 'extract'   && length($paramValue) ) {
		    if ( $paramValue =~ /\|/ ) {
			push @extract, split /\|/, $paramValue;
		    } else {
			push @extract, $paramValue;
		    }
	        } elsif ( lc($paramName) eq 'e-value'  && length($paramValue) ) {
		    $evalue   = $paramValue;
	        } elsif ( lc($paramName) eq 'identity' && length($paramValue) ) {
	            $identity = $paramValue;
	        } elsif ( lc($paramName) eq 'direct' && length($paramValue) ) {
	            $direct = $paramValue;
	        }
	    } else {
		$category = $_;
	    }
        }
    }

    # input parameter when user access G-Links without REST interface
    if ( $q->param('format') ) {
	$format = $q->param('format');
    }
    if ( $q->param('filter') ) {
        @filter = split /;/, $q->param('filter');
    }
    if ( $q->param('extract') ) {
        @extract = split /;/, $q->param('extract');
    }
    if ( $q->param('e-value') ) {
        $evalue = $q->param('e-value');
    }
    if ( $q->param('identity') ) {
        $identity = $q->param('identity');
    }
    if ( $q->param('direct') ) {
        $direct = $q->param('direct');
    }

    if ( $format && ( $format eq 'note' || $format eq 'slim' ) ) {
	$format = 'genie';
    }

    if ( ! $format || $format ne 'genie' ) {
	# 'HTTP and Content Negotiation' (Cool URIs)
	# W3C [http://www.w3.org/TR/2008/NOTE-cooluris-20080331/#conneg]
	$format = _content_negotiation( $format, \%ENV );

	# if given category, data-get mode. format is restricted to 'out'
	if ( $category ) {
	    $format = 'out';
	}
    }

    # set suitable Content header for data format
    my $header = $format eq 'html' ? $q->header( -type => 'text/html'   ) :
                 $format eq 'json' ? $q->header( -type => 'text/json'   ) :
                 $format eq 'rdf'  ? $q->header( -type => 'text/rdf'    ) :
                 $format eq 'nt'   ? $q->header( -type => 'text/rdf+n3' ) :
		                     $q->header( -type => 'text/plain'  );

    # annotator( ID, output format, filter, extract, e-value, identity)
    my $result = annotator($id, $format, \@filter, \@extract, $evalue, $identity, $direct);

    if ( $category ) {
	# retrieve datasets via other web-based services
	print $header,retrieve_dataset( $result, $category );
    } else {
	# output ID list and Descriptions
	print $header,$result;
    }
} else {
    # if not given query, redirect to Wiki page
    print $q->redirect('http://www.g-language.org/wiki/glinks');
}

# $format = _content_negotiation( $format, \%ENV );
# Content Negotiation (specified suitable format)
sub _content_negotiation {
    my $format = lc shift;

    # retrieve USER_AGENT and HTTP_ACCEPT
    my $agent  = $_[0]->{'HTTP_USER_AGENT'};
    my $accept = $_[0]->{'HTTP_ACCEPT'};


    if ( $format ) {
	# [user specifies data format] => user's query has priority

	# format 'n3' is same as 'nt' (Notation 3)
	if ($format eq 'n3') {
	    $format = 'nt';
	}

	# format 'txt', 'tsv' and 'out' output Tabular format
	if ( $format eq 'txt' || $format eq 'tsv' ) {
	    $format = 'out';
	}

	# set 'out' (default value)
	unless ( $format eq 'html' ||
		 $format eq 'json' ||
		 $format eq 'nt'   ||
		 $format eq 'rdf'  ) {
	    # [user specify incorrect format] => set default value
	    $format = 'out';
	}
    } else {
	# [user does not specify data format] => auto detect

	if ( $accept ) {
	    # [web server receives HTTP_ACCEPT]
	    my ($type) = split(/,/, $accept);

	    if (      $type eq 'text/plain' ) {
		$format = 'out';
	    } elsif ( $type eq 'text/html' ) {
		$format = 'html';
	    } elsif ( $type eq 'text/json' ) {
		$format = 'json';
	    } elsif ( $type eq 'text/rdf' ) {
		$format = 'rdf';
	    } elsif ( $type eq 'text/rdf+n3' || $type eq 'text/n3' ) {
		$format = 'nt';
	    }
	}


	if ( !$format && $agent && $agent =~ m/^Mozilla/ ) {
	    # [User accesses via Web Borwser]
	    $format = 'html';
	}

	unless ( $format ) {
	    # [format is not detected]
	    $format = 'out';
	}
    }

    return $format;
}
