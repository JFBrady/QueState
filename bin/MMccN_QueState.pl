#!/usr/bin/perl -w

=head1 NAME

MMccN_QueState.pl

=head1 SYNOPSIS

MMccN_QueState.pl

=head1 DESCRIPTION

Computes MMccN QueState Probabilities and Service Levels

=head1 OPTIONS

 -h display help text
 -t create trace files

=head1 EXAMPLES

 MMccN_QueState.pl -t

=cut

##########################################################################
# Perl Script:                                                           #
# Purpose: Calculates MMccN QueState Probabilities and Service Levels    #
# Author:    James F Brady                                               #
# Copyright: © Copyright 2020, James F Brady, All rights reserved        #
##########################################################################
require 5.004;
use strict;
use Getopt::Std;
use vars qw($opt_h $opt_t);

my($yyyymmddhhmmss);
my($daydatetime);
my($infile);
my($infile1);
my($infile_list_ref);
my(@row_parts);
my($row_size);
my($lamda);
my($lamda_e);
my($mu);
my($a_src);
my($ai_src);
my($a_carried);
my($a_intended);
my($a_offered);
my($c);
my($N);
my($M);
my($rho);
my($rho_used);
my($denom);
my($denom1);
my($pblock);
my($pblock1);
my($pstate_ref);
my($pstate1_ref);
my($pstate_val);

my($heading);
my($out_record_ref);
my(@out_records);
my($out_file);
my($trace_ref);
my(@traces);

my($p_sum)=0;
my($p_sum1)=0;
my($dir_results)='MMccN_QueState_Results';
my($dir_traces)='MMccN_QueState_Traces';

################################
# Check command line options   #
################################
getopts('ht');

################################
# Display help text            #
################################
if ($opt_h)
{
  system ("perldoc",$0);
  exit 0;
}

#####################################
# Get Run Timestamp                 #
#####################################
($yyyymmddhhmmss,$daydatetime) = get_run_date();

###########################
# Create input file list  #
###########################
$infile_list_ref = create_infile_list();
if (!@$infile_list_ref)
{
  print "Error - No input files\n";
  exit(0);
}


################################
# Process input file list      #
################################
print "\nMMccN QueState: $daydatetime\n";
foreach $infile (@$infile_list_ref)
{
  if (!open INFILE,$infile)
  {
    print "Error - $infile failed to open\n"; 
    next;
  }
  ######################################
  # Print name of file being processed #
  ######################################
  print " - $infile\n";

  ################################
  # Read input file              #
  ################################
  while (<INFILE>)
  {
    chomp $_;
    if (!$heading)
    {
      $heading=1;
      next;
    }

    ######################################
    # Split the row into parts           #
    ######################################
    (@row_parts) = split ('\,',$_);
    $row_size = @row_parts;

    ######################################
    # Check Row Size                     #
    ######################################
    if ($row_size ne 4)
    {
      print "\nError $infile: Wrong Size Records in Row - @row_parts\n"; 
      next;
    }

    ######################################
    # Input Parameters                   #
    ######################################
    ($c,$N,$lamda,$mu) = split('\,',$_);

    ###########################################
    # Intended Offered Load Per Idle Source   #
    ###########################################
    $a_src=$lamda/$mu/$N;
    $ai_src=$a_src/(1-$a_src);

    ################################
    # Arrival View M=N-1           #
    ################################
    $M = $N-1;

    #####################################
    # Calculate denom for Observer View #
    #####################################
    ($denom) = denom($ai_src,$c,$N);

    ####################################
    # Calculate denom for Arrival View #
    ####################################
    ($denom1) = denom($ai_src,$c,$M);

    ##########################################
    # Calculate pstate_ref for Observer View #
    ##########################################
    ($pstate_ref) = p_term($ai_src,$c,$N,$denom);
    foreach $pstate_val (@$pstate_ref)
    {
      $p_sum += $pstate_val;
    }

    #########################################
    # Calculate pstate_ref for Arrival View #
    #########################################
    ($pstate1_ref) = p_term($ai_src,$c,$M,$denom1);
    foreach $pstate_val (@$pstate1_ref)
    {
      $p_sum1 += $pstate_val;
    }

    #######################################
    # Calculate pblock for Observer View  #
    #######################################
    $pblock = 1-($p_sum-$pstate_ref->[$c]);

    ######################################
    # Calculate pblock for Arrival View  #
    ######################################
    $pblock1 = 1-($p_sum1-$pstate1_ref->[$c]);

    #################################
    # Effective Arrival Rate        #
    #################################
    $lamda_e = $lamda*(1-$pstate_ref->[$c]);

    #################################
    # Intended Offered Load         #
    #################################
    $a_intended = $N*$ai_src/(1+$ai_src);

    #################################
    # Carried Load                  #
    #################################
    $a_carried = $a_intended*(1-(1-$c/$N)*$pstate_ref->[$c]);

    #################################
    # Offered Load                  #
    #################################
    $a_offered = $a_carried/(1-$pstate1_ref->[$c]);

    #################################
    # Offered Load                  #
    #################################
    $a = $lamda/$mu;

    ######################################
    # Traffic Intensity                  #
    ######################################
    $rho = $lamda/($c*$mu);

    #################################
    # Utilization Factor            #
    #################################
    $rho_used = $rho*(1-$pstate_ref->[$c]);

    ################################
    # Create Output Records        #
    ################################
    ($out_record_ref) = out_record($daydatetime,$c,$N,$lamda,$mu,$lamda_e,
                                   $ai_src,$a_intended,$a_carried,$a_offered,
				   $rho,$rho_used,
                                   $pblock,$pblock1,$p_sum,$p_sum1,
                                   $pstate_ref,$pstate1_ref);
    push @out_records,@$out_record_ref;

    ################################
    # Create Trace Data - opt_t    #
    ################################
    if($opt_t)
    {
      ($trace_ref) = trace($daydatetime,$c,$N,$lamda,$mu,$rho,
                           $denom,$denom1,$p_sum,$p_sum1,$pstate_ref,$pstate1_ref);
      push @traces,@$trace_ref;
    }

    ################################
    # Undef Variables              #
    ################################
    undef $p_sum;
    undef $p_sum1;
  }
  ################################
  # Create Output Records        #
  ################################
  if(@out_records)
  {
    ($infile1) = split('\.',$infile);
    $out_file = join '_',$infile1,'results',$yyyymmddhhmmss;
    $out_file = join '.',$out_file,'csv';
    create_output($dir_results,$out_file,\@out_records);
  }
  ################################
  # Create Output Records        #
  ################################
  if(@traces)
  {
    ($infile1) = split('\.',$infile);
    $out_file = join '_',$infile1,'traces',$yyyymmddhhmmss;
    $out_file = join '.',$out_file,'txt';
    create_output($dir_traces,$out_file,\@traces);
  }
  ################################
  # Undef Variables              #
  ################################
  undef $heading;
  undef @out_records;
  undef @traces;
}


sub
denom
{
  my($ai_src,$c,$N) = @_;

  my($n);

  my($term1)=1;
  my($term2)=$N;
  my($term3)=1;
  my($nn)=1;
  my($denom)=1;

  ################################
  # Calculate denom              #
  ################################
  for($n=0;$n<$c;$n++)
  {
    $term2 = $N-$n;
    $term1=$term1*$term2;
    $nn = $nn*($n+1);
    $term3=$term3*$ai_src;
    $denom += $term1/$nn*$term3;
  }
  return($denom);
}


sub
p_term
{
  my($ai_src,$c,$N,$denom) = @_;

  my($n);
  my($term2);
  my($term4);
  my(@pstate);

  my($term1)=1;
  my($term3)=1;
  my($nn)=1;

  ################################
  # Calculate denom              #
  ################################
  $pstate[0]=1/$denom;
  for($n=0;$n<$c;$n++)
  {
    $term2 = $N-$n;
    $term1=$term1*$term2;
    $nn = $nn*($n+1);
    $term3=$term3*$ai_src;
    $term4 = $term1/$nn*$term3;
    $pstate[$n+1] = $term4/$denom;
  }
  return(\@pstate);
}


sub
out_record
{
  my($daydatetime,$c,$N,$lamda,$mu,$lamda_e,
     $ai_src,$a_intended,$a_carried,$a_offered,
     $rho,$rho_used,
     $pblock,$pblock1,$p_sum,$p_sum1,
     $pstate_ref,$pstate1_ref) = @_;

  my($row);
  my($record);
  my($record1);
  my(@out_record);
  my($j);

  #################
  # Results Data  #
  #################
  $row = "\nMMccN QueState Results: $daydatetime";
  push @out_record,$row;

  ######################################
  # Performance Statistics             #
  ######################################
  $row = join ',','c','N','lamda','mu','lamda_e',
                  'ai_src','a_intended','a_carried','a_offered',
                  'rho','rho_used';
  push @out_record,$row;
  $row = join ',',$c,$N,$lamda,$mu,$lamda_e,
		  $ai_src,$a_intended,$a_carried,$a_offered,
                  $rho,$rho_used;
  push @out_record,$row;
  $row = join ',','Statistics','p[block]','p_sum';
  push @out_record,$row;
  $row = join ',','Observer',$pblock,$p_sum;
  push @out_record,$row;
  $row = join ',','Arrival',$pblock1,$p_sum1;
  push @out_record,$row;

  ######################################
  # State Probabilities                #
  ######################################
  $row = join ',','StateProb';
  $record = join ',','Observer';
  $record1 = join ',','Arrival';
  for($j=0;$j<=$c;$j++)
  {
    $row = join ',',$row,"p[$j]";
    $record = join ',',$record,$pstate_ref->[$j];
    $record1 = join ',',$record1,$pstate1_ref->[$j];
  }
  push @out_record,$row;
  push @out_record,$record;
  push @out_record,$record1;

  return(\@out_record)

}


sub
trace
{
  my($daydatetime,$c,$N,$lamda,$mu,$rho,
     $denom,$denom1,$p_sum,$p_sum1,$pstate_ref,$pstate1_ref) =  @_;

  my ($row);
  my (@trace);
  my ($record);

  my ($j)=0;
  my ($i)=0;

  ##############
  # Trace Date #
  ##############
  $row = "\nMMccN QueState Trace Data: $daydatetime";
  push @trace,$row;

  ######################################
  # Input Parameters                   #
  ######################################
  $row = join ' ',"c=$c","N=$N","lamda=$lamda","mu=$mu","rho=$rho";
  push @trace,$row;

  #####################################
  # p[0] - p0_t1 p0_t2 p0_t3 p(zero)  #
  #####################################
  $row = join ' ',"denom=$denom";
  push @trace,$row;

  ################################
  # p[n] - pn_0_c                #
  ################################
  foreach $record (@$pstate_ref)
  {
    $row = join '','pstate[',sprintf('%03d',$j++),']=',$record;
    push @trace,$row;
  }

  ################################
  # pn                           #
  ################################
  $row = join ' ',"p_sum=$p_sum";
  push @trace,$row;

  #####################################
  # p[0] - p0_t1 p0_t2 p0_t3 p(zero)  #
  #####################################
  $row = join ' ',"denom1=$denom1";
  push @trace,$row;

  ################################
  # p[n] - pn_0_c                #
  ################################
  foreach $record (@$pstate1_ref)
  {
    $row = join '','pstate1[',sprintf('%03d',$i++),']=',$record;
    push @trace,$row;
  }

  ################################
  # pn                           #
  ################################
  $row = join ' ',"p_sum1=$p_sum1";
  push @trace,$row;

  return(\@trace);
}


sub
get_run_date
{
  my ($hour);
  my ($min);
  my ($sec);
  my ($hhmmss);
  my ($year);
  my ($month);
  my ($day);
  my ($yyyymmdd);
  my ($date);
  my ($daydate);
  my ($daydatetime);
  my ($yyyymmddhhmmss);

  my ($day_of_week)=' ';
  my (@day_of_week_list) = ('Sunday','Monday','Tuesday','Wednesday',
                            'Thursday','Friday','Saturday');

  #####################
  #  Get current date #
  #####################
  ($sec,$min,$hour,$day,
   $month,$year,$day_of_week) = localtime(time);

  #########################
  #  Create output values #
  #########################
  $sec = sprintf('%02d',$sec);
  $min = sprintf('%02d',$min);
  $hour = sprintf('%02d',$hour);
  $hhmmss = join ':',$hour,$min,$sec;

  $day = sprintf('%02d',$day);
  $month = sprintf('%02d',$month+1);
  $year = sprintf('%04d',$year+1900);
  $yyyymmdd = join '',$year,$month,$day;
  $yyyymmddhhmmss = join '',$yyyymmdd,$hour,$min,$sec;

  $date = join '/',$month,$day,$year;
  $daydate = join ' ',$day_of_week_list[$day_of_week],$date;
  $daydatetime = join ' ',$daydate,$hhmmss;

  return($yyyymmddhhmmss,$daydatetime);
}


sub
create_infile_list
{
  my ($file);
  my ($infile_name);
  my ($infile_ext);
  my (@all_files);
  my (@infile_list);

  ##############################
  # Get all file names         #
  ##############################
  opendir(DIR,'.');
  @all_files = readdir(DIR);
  closedir(DIR);

  ##############################
  # Create infile list         #
  ##############################
  foreach $file (@all_files)
  {
    ($infile_name,$infile_ext) = split('\.',$file);
    if ($infile_ext)
    {
      if ($infile_ext eq 'txt')
      {
        push @infile_list,$file;
      }
    }
  }

  ################################
  # Sort infile list             #
  ################################
  @infile_list = sort @infile_list;

  return(\@infile_list);
}


sub
create_output
{
  my ($outdir,$outfile,$list_ref) = @_;

  my ($list_val);

  ################################################
  # Create output directory and open output file #
  ################################################
  if ($outdir)
  {
    mkdir $outdir,0777;
    open OUTFILE, ">$outdir/$outfile";
  }
  else
  {
    open OUTFILE, ">$outfile";
  }
  ##############################
  # Output list                #
  ##############################
  foreach $list_val (@$list_ref)
  {
    print OUTFILE "$list_val\n";
  }
  close OUTFILE;

  return(0);
}
