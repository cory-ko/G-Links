#!/usr/bin/env perl

package Restauro::Init;

use warnings;
use strict;

use base 'Exporter';
our @EXPORT = qw/ init_info /;

# Variables
my ($jobid, $offset, $base_path, $tmp_path, $job_path, $db_path);

# load default settings (values)
sub init_info {
    $base_path = '/var/www/html/glinks/';
    $db_path   = './db/';
    $jobid     = _generate_jobid($base_path);
    $tmp_path  = $base_path.'/tmp/'.$jobid.'/';
    $job_path  = $base_path.'/tmp/'.$jobid.'/';

    mkdir(       $job_path );
    chmod( 0777, $job_path );

    return {
	    'base_path'    => $base_path,
	    'db_path'      => $db_path,
	    'jobid'        => $jobid,
            'evalue'       => 1e-70,
            'identity'     => 0.98,
	    'tmp_path'     => $tmp_path,
	    'job_path'     => $job_path,
	    'query_sprot'  => $job_path.'query.fasta',
	    'DB_sprot'     => [
			       $db_path.'/sprot.fasta',
			      ],
	    'info_sprot'   => [
			       $db_path.'/sprot.info',
			      ],
	   };
}

sub _generate_jobid {
    my $base_path = shift;

    my $jobid = ( (time % 1296000)*10 + int(rand(10)) + 1048576);

    while ( -d $base_path.'/'.$jobid || -e $base_path.'/'.$jobid.'.gbk' ) {
        $jobid = ( (time % 1296000)*10 + int(rand(10)) + 1048576);
    }

    return $jobid;
}

1;
