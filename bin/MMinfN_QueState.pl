#!/usr/bin/perl -w

=head1 NAME

MMinfN_QueState.pl

=head1 SYNOPSIS

MMinfN_QueState.pl

=head1 DESCRIPTION

Computes MMinfN (Binomial) Dist QueState Probabilities and Service Levels

=head1 OPTIONS

 -h display help text
 -t create trace files

=head1 EXAMPLES

 MMinfN_QueState.pl -t

=cut

##########################################################################
# Perl Script:                                                           #
# Purpose: Calculates MMinfN QueState Probabilities and Service Levels   #
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
my($mu);
my($a);
my($a_src);
my($c);
my($k);
my($N);
my($M);
my($u);
my($n);
my($rho);
my($pstate_ref);
my($pstate1_ref);
my($pstate_val);
my($pblock);
my($pblock1);

my($heading);
my($out_record_ref);
my(@out_records);
my($out_file);
my($trace_ref);
my(@traces);

my($p_sum)=0;
my($p_sum1)=0;
my($psum_c_minus_1)=0;
my($psum1_c_minus_1)=0;
my($dir_results)='MMinfN_QueState_Results';
my($dir_traces)='MMinfN_QueState_Traces';

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
print "\nMMinfN QueState: $daydatetime\n";
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

    ######################################
    # Check if N < c                     #
    ######################################
    if ($N<$c)
    {
      print "\nError $infile: N less than c (N=$N < c=$c) in Row - @row_parts\n"; 
      next;
    }

    #################################
    # Offered Load                  #
    #################################
    $a = $lamda/$mu;
    $a_src=$lamda/$mu/$N;

    ################################
    # Arrival View M=N-1           #
    ################################
    $M = $N-1;    

    ##########################################
    # Calculate pstate_ref for Observer View #
    ##########################################
    ($pstate_ref) = psn($a_src,$c,$N);
    foreach $pstate_val (@$pstate_ref)
    {
      $p_sum += $pstate_val;
    }

    ##########################################
    # Calculate pstate_ref for Arrival View  #
    ##########################################
    ($pstate1_ref) = psn($a_src,$c,$M);
    foreach $pstate_val (@$pstate1_ref)
    {
      $p_sum1 += $pstate_val;
    }

    #######################################
    # Calculate pblock for Observer View  #
    #######################################
     for($n=0;$n<$c;$n++)
    {
      $psum_c_minus_1 += $pstate_ref->[$n];
    }
    $pblock = 1-$psum_c_minus_1;

    ######################################
    # Calculate pblock for Arrival View  #
    ######################################
     for($n=0;$n<$c;$n++)
    {
      $psum1_c_minus_1 += $pstate1_ref->[$n];
    }
    $pblock1 = 1-$psum1_c_minus_1;

    ######################################
    # Traffic Intensity                  #
    ######################################
    $rho = $lamda/($c*$mu);

    ################################
    # Create Output Records        #
    ################################
    ($out_record_ref) = out_record($daydatetime,$c,$N,$lamda,$mu,
                                   $a_src,$a,$rho,
                                   $pblock,$pblock1,$p_sum,$p_sum1,
                                   $pstate_ref,$pstate1_ref);
    push @out_records,@$out_record_ref;

    ################################
    # Create Trace Data - opt_t    #
    ################################
    if($opt_t)
    {
      ($trace_ref) = trace($daydatetime,$c,$N,$lamda,$mu,$rho,
                           $p_sum,$p_sum1,$pstate_ref,$pstate1_ref);
      push @traces,@$trace_ref;
    }

    ################################
    # Undef Variables              #
    ################################
    undef $p_sum;
    undef $p_sum1;
    undef $psum_c_minus_1;
    undef $psum1_c_minus_1;
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
psn
{
  my($a_src,$c,$N) = @_;

  my($i);
  my(@pstate);

  ################################
  # Calculate Load Per Source    #
  ################################
  $pstate[0]=(1-$a_src)**$N;
  for($i=1;$i<=$N;$i++)
  {
    $pstate[$i] = ($N-$i+1)/($i*(1-$a_src))*$a_src*$pstate[$i-1];
  }
  return(\@pstate);
}


sub
psn1
{
  my($a_src,$c,$N) = @_;

  my($i);
  my(@pstate1);

  ################################
  # Calculate Load Per Source    #
  ################################
  $pstate1[0]=(1-$a_src)**($N-1);
  for($i=1;$i<$N;$i++)
  {
    $pstate1[$i] = ($N-$i)/($i*(1-$a_src))*$a_src*$pstate1[$i-1];
  }
  return(\@pstate1);
}


sub
out_record
{
  my($daydatetime,$c,$N,$lamda,$mu,
     $a_src,$a,$rho,
     $pblock,$pblock1,$p_sum,$p_sum1,
     $pstate_ref,$pstate1_ref) = @_;     

  my ($row);
  my ($record);
  my ($record1);
  my (@out_record);
  my($j);

  #################
  # Results Data  #
  #################
  $row = "\nMMinfN QueState Results: $daydatetime";
  push @out_record,$row;

  ######################################
  # Performance Statistics             #
  ######################################
  $row = join ',','c','N','lamda','mu','a_src','a','rho';
  push @out_record,$row;
  $row = join ',',$c,$N,$lamda,$mu,$a_src,$a,$rho;
  push @out_record,$row;
  $row = join ',','Statistics','p[block]','p_sum';
  push @out_record,$row;
  $row = join ',','Observer',$pblock,$p_sum;
  push @out_record,$row;
  $row = join ',','Arrival',$pblock1,$p_sum1;
  push @out_record,$row;

  #######################################
  # State Probabilities - Observer View #
  #######################################
  $row = join ',','StateProb';
  $record = join ',','Observer';
  for($j=0;$j<=$N;$j++)
  {
    $row = join ',',$row,"p[$j]";
    $record = join ',',$record,$pstate_ref->[$j];
  }
  push @out_record,$row;
  push @out_record,$record;

  ######################################
  # State Probabilities - Arrival View #
  ######################################
  $record1 = join ',','Arrival';
  for($j=0;$j<=$N-1;$j++)
  {
    $record1 = join ',',$record1,$pstate1_ref->[$j];
  }
  push @out_record,$record1;
  return(\@out_record)

}


sub
trace
{
  my($daydatetime,$c,$N,$lamda,$mu,$rho,
     $p_sum,$p_sum1,$pstate_ref,$pstate1_ref) = @_;

  my ($row);
  my (@trace);
  my ($record);

  my ($j)=0;

  ##############
  # Trace Date #
  ##############
  $row = "\nMMinfN QueState Trace Data: $daydatetime";
  push @trace,$row;

  ######################################
  # Input Parameters                   #
  ######################################
  $row = join ' ',"c=$c","N=$N","lamda=$lamda","mu=$mu","rho=$rho";
  push @trace,$row;

  ################################
  # pstate[n]                    #
  ################################
  foreach $record (@$pstate_ref)
  {
    $row = join '','pstate[',sprintf('%03d',$j++),']=',$record;
    push @trace,$row;
  }

  ################################
  # p_sum                        #
  ################################
  $row = join ' ',"p_sum=$p_sum\n";
  push @trace,$row;

  ################################
  # pstate1[n]                   #
  ################################
  foreach $record (@$pstate1_ref)
  {
    $row = join '','pstate1[',sprintf('%03d',$j++),']=',$record;
    push @trace,$row;
  }

  ################################
  # p_sum1                       #
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
