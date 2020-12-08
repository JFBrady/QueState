#!/usr/bin/perl -w

=head1 NAME

MMc_QueState.pl

=head1 SYNOPSIS

MMc_QueState.pl

=head1 DESCRIPTION

Computes MMc QueState Probabilties (Calc 0-k) and Service Levels

=head1 OPTIONS

 -h display help text
 -t create trace files

=head1 EXAMPLES

 MMc_QueState.pl -t

=cut

##########################################################################
# Perl Script:                                                           #
# Purpose: Calculates MMc QueState Probabilties (0-k) and Service Levels #
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
my($c);
my($k);
my($t);
my($kk);
my($rho);
my($pzero);
my($p0_t1);
my($p0_t2);
my($p0_t3);
my(@pstate);
my($pstate_val);
my($pstate_0_c_ref);
my($pstate_0_c_val);
my($pstate_c_k_ref);
my($pstate_c_k_val);
my($p_sum);
my($pq);
my($pqt);
my($pqtq);
my($pst);
my($enq);
my($ens);
my($eqt);
my($eqtq);
my($est);

my($heading);
my($out_record_ref);
my(@out_records);
my($out_file);
my($trace_ref);
my(@traces);

my($pn_0_c)=0;
my($pn_c_k)=0;
my($dir_results)='MMc_QueState_Results';
my($dir_traces)='MMc_QueState_Traces';

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
print "\nMMc QueState: $daydatetime\n";
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
    if ($row_size ne 5)
    {
      print "\nError $infile: Wrong Size Records in Row - @row_parts\n"; 
      next;
    }

    ######################################
    # Input Parameters                   #
    ######################################
    ($c,$k,$lamda,$mu,$t) = split('\,',$_);

    ######################################
    # Check if k <= c                     #
    ######################################
    if ($k<=$c)
    {
      print "\nError $infile: p[show] must be > c (p[show]=$k <= c=$c) "; 
      print "- @row_parts\n"; 
      next;
    }   

    #################################
    # Offered Load                  #
    #################################
    $a = $lamda/$mu;

    ######################################
    # Traffic Intensity                  #
    ######################################
    $rho = $lamda/($c*$mu);

    ######################################
    # Check For Overload                 #
    ######################################
    if ($rho >= 1)
    { 
      print "\nError $infile: lamda > (c*mu) ";
      print "{lamda/(c*mu)=$rho} in Row - @row_parts\n"; 
      next;
    }

    ######################################
    # k-c                                #
    ######################################
    $kk = $k-$c;

    ################################
    # Calculate p[0] - p0_t1       #
    ################################
    ($p0_t1) = p0_t1($a,$c);

    ################################
    # Calculate p[0] - p0_t2       #
    ################################
    ($p0_t2) = p0_t2($a,$c);

    ################################
    # Calculate p[0] - p0_t3       #
    ################################
    ($p0_t3) = p0_t3($rho);

    ################################
    # Calculate p[0]               #
    ################################
    $pzero = 1/($p0_t1+($p0_t2*$p0_t3));

    ################################
    # Calculate p[n] - pn_0_c      #
    ################################
    ($pstate_0_c_ref) = pn_0_c($a,$c,$pzero);
    foreach $pstate_0_c_val (@$pstate_0_c_ref)
    {
      $pn_0_c += $pstate_0_c_val;
    }

    ################################
    # Calculate p[n] - pn_c_k      #
    ################################
    ($pstate_c_k_ref) = pn_c_k($a,$c,$kk,$p0_t2,$pzero);
    foreach $pstate_c_k_val (@$pstate_c_k_ref)
    {
      $pn_c_k += $pstate_c_k_val;
    }

    ####################################
    # Calculate p[n] = pn_0_c + pn_c_k #
    ####################################
    $p_sum=$pn_0_c+$pn_c_k;

    ################################
    # Calculate pstate[n]          #
    ################################
    push @pstate,@$pstate_0_c_ref,@$pstate_c_k_ref;

    #################################
    # Prob Queue and Queue > t      #
    #################################
    $pq = (1-($pn_0_c-$pstate[$c]));
    $pqtq = exp(-(1-$rho)*$c*$mu*$t);
    $pqt = $pq*$pqtq;

    #################################
    # Prob System > t               #
    #################################
    if($a == $c-1)
    {
      $pst = (1+($pq*$t*$mu))*exp(-$t*$mu);
    }
    else
    {
      $pst = 1-(1+(($a-$c+1-$pq)/($c-1-$a)*exp(-$t*$mu))+
             ($pq/($c-1-$a)*exp(-(1-$a/$c)*$c*$t*$mu)));
    }

    ######################################
    # Expected Values - Number and Time  #
    ######################################
    ($enq) = enq($p0_t2,$rho,$pzero);
    $eqt = $enq/$lamda;
    $ens = $enq+$a;
    $est = $ens/$lamda;
    $eqtq = $eqt/($pq);

    ################################
    # Create Output Records        #
    ################################
    ($out_record_ref) = out_record($daydatetime,$c,$k,$lamda,$mu,$t,
                                   $a,$rho,
                                   $enq,$ens,$eqt,$est,$eqtq,
                                   $pq,$pqt,$pst,$pqtq,$p_sum,\@pstate);
    push @out_records,@$out_record_ref;

    ################################
    # Create Trace Data - opt_t    #
    ################################
    if($opt_t)
    {
      ($trace_ref) = trace($daydatetime,$c,$k,$lamda,$mu,$rho,
                           $p0_t1,$p0_t2,$p0_t3,$pzero,
                           $pstate_0_c_ref,$pn_0_c,
                           $pstate_c_k_ref,$pn_c_k,$p_sum);
      push @traces,@$trace_ref;
    }

    ################################
    # Undef Variables              #
    ################################
    undef $pn_0_c;
    undef $pn_c_k;
    undef @pstate;
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
p0_t1
{
  my($a,$c) = @_;

  my($n);

  my($term1)=1;
  my($nn)=1;
  my($p0_t1)=1;

  ################################
  # Calculate p(zero) - p0_t1    #
  ################################
  if ($c>1)
  {
    for($n=0;$n<$c-1;$n++)
    {
      $term1 = $term1*$a;
      $nn = $nn*($n+1);
      $p0_t1 = $p0_t1+$term1/$nn;
    }
  }
  return($p0_t1);
}


sub
p0_t2
{
  my($a,$c) = @_;

  my($n);

  my($term1)=1;
  my($nn)=1;
  my($p0_t2)=1;

  ################################
  # Calculate p(zero) - p0_t2    #
  ################################
  for($n=0;$n<$c;$n++)
  {
    $term1 = $term1*$a;
    $nn = $nn*($n+1);
    $p0_t2 = $term1/$nn;
  }
  return($p0_t2);
}


sub
p0_t3
{
  my($rho) = @_;

  my($p0_t3);

  ################################
  # Calculate p(zero) - p0_t3    #
  ################################
  $p0_t3 = 1/(1-$rho);

  return($p0_t3);
}


sub
pn_0_c
{
  my($a,$c,$pzero) = @_;

  my($n);
  my(@pstate_0_c);

  my($term1)=1;
  my($term2)=0;
  my($nn)=1;

  ################################
  # Calculate p(n) - pn_0_c      #
  ################################
  $pstate_0_c[0]=$pzero;
  for($n=1;$n<=$c;$n++)
  {
    $term1 = $term1*$a;
    $nn = $nn*$n;
    $term2 = $term1/$nn;
    $pstate_0_c[$n] = $term2*$pstate_0_c[0];
  }
  return(\@pstate_0_c);
}


sub
pn_c_k
{
  my($a,$c,$kk,$p0_t2,$pzero) = @_;

  my($n);
  my(@pstate_c_k);

  my($term1)=1;
  my($nn)=$c;
  
  ################################
  # Calculate p(n) - pn_c_k      #
  ################################
  for($n=1;$n<=$kk;$n++)
  {
    $term1 = $term1*$a/$c;
    $nn = $nn*$c;
    $pstate_c_k[$n-1] = $p0_t2*$term1*$pzero;
  }
  return(\@pstate_c_k);
}


sub
enq
{
  my($p0_t2,$rho,$pzero) = @_;

  my($enq)=0;

  ################################
  # Calculate p(n) - pn_c_k      #
  ################################
  $enq = $p0_t2*$rho/(1-$rho)**2*$pzero;

  return($enq);
}


sub
out_record
{
  my($daydatetime,$c,$k,$lamda,$mu,$t,
     $a,$rho,
     $enq,$ens,$eqt,$est,$eqtq,
     $pq,$pqt,$pst,$pqtq,$p_sum,$pstate_ref) = @_;

  my ($row);
  my ($record);
  my (@out_record);
  my($j);

  #################
  # Results Data  #
  #################
  $row = "\nMMc QueState Results: $daydatetime";
  push @out_record,$row;

  ######################################
  # Performance Statistics             #
  ######################################
  $row = join ',','c','p[show]','lamda','mu','t','a','rho',
                  'E(nq)','E(ns)','E(qt)','E(st)','E(qt/q)',
                  'p[q]','p[q>t]','p[s>t]','p[q>t/q]','p_sum';
  push @out_record,$row;
  $row = join ',',$c,$k,$lamda,$mu,$t,$a,$rho,
                  $enq,$ens,$eqt,$est,$eqtq,
                  $pq,$pqt,$pst,$pqtq,$p_sum;
  push @out_record,$row;

  ######################################
  # State Probabilities                #
  ######################################
  $row='StateProb';
  $record='QSystem';
  for($j=0;$j<=$k;$j++)
  {
    $row = join ',',$row,"p[$j]";
    $record = join ',',$record,$pstate_ref->[$j];
  }
  push @out_record,$row;
  push @out_record,$record;

  return(\@out_record)

}



sub
trace
{
  my($daydatetime,$c,$k,$lamda,$mu,$rho,
     $p0_t1,$p0_t2,$p0_t3,$pzero,
     $pstate_0_c_ref,$pn_0_c,
     $pstate_c_k_ref,$pn_c_k,$p_sum) =  @_;

  my ($row);
  my (@trace);
  my ($record);

  my ($j)=0;

  ##############
  # Trace Date #
  ##############
  $row = "\nMMc QueState Trace Data: $daydatetime";
  push @trace,$row;

  ######################################
  # Input Parameters                   #
  ######################################
  $row = join ' ',"c=$c","k=$k","lamda=$lamda","mu=$mu","rho=$rho","kk=$kk";
  push @trace,$row;

  #####################################
  # p[0] - p0_t1 p0_t2 p0_t3 p(zero)  #
  #####################################
  $row = join ' ',"pzero=$pzero","p0_t1=$p0_t1","p0_t2=$p0_t2","p0_t3=$p0_t3";
  push @trace,$row;

  ################################
  # p[n] - pn_0_c                #
  ################################
  foreach $record (@$pstate_0_c_ref)
  {
    $row = join '','pstate_0_c_val[',sprintf('%03d',$j++),']=',$record;
    push @trace,$row;
  }
  $row = join ' ',"pn_0_c=$pn_0_c";
  push @trace,$row;

  ################################
  # p[n] - pn_c_k                #
  ################################
  foreach $record (@$pstate_c_k_ref)
  {
    $row = join '','pstate_c_k_val[',sprintf('%03d',$j++),']=',$record;
    push @trace,$row;
  }
  $row = join ' ',"pn_c_k=$pn_c_k";
  push @trace,$row;

  ################################
  # p_sum                        #
  ################################
  $row = join ' ',"p_sum=$p_sum";
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
