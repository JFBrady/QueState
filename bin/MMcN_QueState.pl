#!/usr/bin/perl -w

=head1 NAME

MMcN_QueState.pl

=head1 SYNOPSIS

MMcN_QueState.pl

=head1 DESCRIPTION

Computes MMcN QueState Probabilities and Service Levels

=head1 OPTIONS

 -h display help text
 -t create trace files

=head1 EXAMPLES

 MMcN_QueState.pl -t

=cut

###########################################################################
# Perl Script:                                                            #
# Purpose: Calculates MMcN QueState Probabilities and Service Levels      #
# Author:    James F Brady                                                #
# Copyright: © Copyright 2020, James F Brady, All rights reserved         #
###########################################################################
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
my($a);
my($a_src);
my($ai_src);
my($a_intend);
my($a_offer);
my($c);
my($N);
my($M);
my($t);
my($rho);
my($pzero);
my($pzero_a);
my($p0_t1);
my($p0_t1_a);
my($p0_t2);
my($p0_t2_a);
my($p0_t3);
my($p0_t3_a);
my(@pstate);
my(@pstate_a);
my($pstate_0_c_ref);
my($pstate_0_c_a_ref);
my($pstate_0_c_val);
my($pstate_c_N_ref);
my($pstate_c_N_a_ref);
my($pstate_c_N_val);
my($p_sum);
my($p_sum_a);
my($pq);
my($pq_a);
my($pqt);
my($pqtq);
my($pqt_a);
my($pqtq_a);
my($pst);
my($pst_a);
my($enq);
my($ens);
my($eqt);
my($eqt_a);
my($eqtq);
my($eqtq_a);
my($est);
my($est_a);

my($heading);
my($out_record_ref);
my(@out_records);
my($out_file);
my($trace_ref);
my(@traces);

my($pn_0_c)=0;
my($pn_0_c_a)=0;
my($pn_c_N)=0;
my($pn_c_N_a)=0;
my($dir_results)='MMcN_QueState_Results';
my($dir_traces)='MMcN_QueState_Traces';

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
print "\nMMcN QueState: $daydatetime\n";
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
    ($c,$N,$lamda,$mu,$t) = split('\,',$_);

    ######################################
    # Check if N <= c                     #
    ######################################
    if ($N<=$c)
    {
      print "\nError $infile: N must be greater than c ";
      print "(N=$N and c=$c) in Row - @row_parts\n"; 
      next;
    }   

    #################################
    # Offered Load                  #
    #################################
    $a_src=$lamda/$mu/$N;
    $ai_src=$a_src/(1-$a_src);

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

    ################################
    # p[0]-p0_t1 Observer View     #
    ################################
    ($p0_t1) = p0_t1($ai_src,$c,$N);

    ################################
    # p[0]-p0_t2 Observer View     #
    ################################
    ($p0_t2) = p0_t2($ai_src,$c,$N);

    ################################
    # p[0]-p0_t3 Observer View     #
    ################################
    ($p0_t3) = p0_t3($ai_src,$c,$N,$p0_t2);

    ################################
    # pzero Observer View          #
    ################################
    $pzero = 1/($p0_t1+$p0_t3);

    ################################
    # p[n]-pn_0_c Observer View    #
    ################################
    ($pstate_0_c_ref) = pn_0_c($ai_src,$c,$N,$pzero);
    foreach $pstate_0_c_val (@$pstate_0_c_ref)
    {
      $pn_0_c += $pstate_0_c_val;
    }

    ################################
    # p[n]-pn_c_N Observer View    #
    ################################
    ($pstate_c_N_ref) = pn_c_N($ai_src,$c,$N,$p0_t2,$pzero);
    foreach $pstate_c_N_val (@$pstate_c_N_ref)
    {
      $pn_c_N += $pstate_c_N_val;
    }

    ################################
    # p_sum Observer View          #
    ################################
    $p_sum = $pn_0_c+$pn_c_N;

    ################################
    # pstate[n] Observer View      #
    ################################
    push @pstate,@$pstate_0_c_ref,@$pstate_c_N_ref;

    ################################
    # Arrival View M=N-1           #
    ################################
    $M = $N-1;    

    ################################
    # p[0]-p0_t1_a Arrival View    #
    ################################
    ($p0_t1_a) = p0_t1($ai_src,$c,$M);

    ################################
    # p[0]-p0_t2_a Arrival View    #
    ################################
    ($p0_t2_a) = p0_t2($ai_src,$c,$M);

    ################################
    # p[0]-p0_t3_a Arrival View    #
    ################################
    ($p0_t3_a) = p0_t3($ai_src,$c,$M,$p0_t2_a);

    ################################
    # pzero_a Arrival View         #
    ################################
    $pzero_a = 1/($p0_t1_a+$p0_t3_a);

    ################################
    # p[n]-pn_0_c_a Arrival View   #
    ################################
    ($pstate_0_c_a_ref) = pn_0_c($ai_src,$c,$M,$pzero_a);
    foreach $pstate_0_c_val (@$pstate_0_c_a_ref)
    {
      $pn_0_c_a += $pstate_0_c_val;
    }

    ################################
    # p[n]-pn_c_N_a Arrival View   #
    ################################
    ($pstate_c_N_a_ref) = pn_c_N($ai_src,$c,$M,$p0_t2_a,$pzero_a);
    foreach $pstate_c_N_val (@$pstate_c_N_a_ref)
    {
      $pn_c_N_a += $pstate_c_N_val;
    }

    ################################
    # p_sum_a Arrival View         #
    ################################
    $p_sum_a = $pn_0_c_a+$pn_c_N_a;

    ################################
    # pstate_a[n] Arrival View     #
    ################################
    push @pstate_a,@$pstate_0_c_a_ref,@$pstate_c_N_a_ref;

    #####################################
    # Prob Queue/System - Observer View #
    #####################################
    $pq = $pn_c_N;
    ($pqt) = pqt($c,$N,$mu,$t,\@pstate);
    ($pst) = pst($c,$N,$mu,$t,$pq,\@pstate);
    $pqtq=$pqt/$pq;

    ####################################
    # Prob Queue/System - Arrival View #
    ####################################
    $pq_a = $pn_c_N_a;
    ($pqt_a) = pqt($c,$M,$mu,$t,\@pstate_a);
    ($pst_a) = pst($c,$M,$mu,$t,$pq_a,\@pstate_a);
    $pqtq_a=$pqt_a/$pq_a;

    #################################
    # Effective Arrival Rate        #
    #################################
    ($lamda_e) = lamda_e($N,$lamda,\@pstate);

    ######################################
    # Expected Values - Number and Time  #
    ######################################
    ($enq,$ens) = enq_ens($c,$N,\@pstate);
    $eqt = $enq/$lamda_e;
    $est = $ens/$lamda_e;
    $eqtq = $eqt/$pq;
    ($eqt_a,$est_a) = eqt_est_a($c,$M,$mu,\@pstate_a);
    $eqtq_a = $eqt_a/$pq_a;

    ######################################
    # Total Traffic - Intended/Offered   #
    ######################################
    $a_intend = $N*$ai_src/(1+$ai_src);
    $a_offer = $N/$mu/(1/$mu/$ai_src+$est);

    ################################
    # Create Output Records        #
    ################################
    ($out_record_ref) = out_record($daydatetime,$c,$N,$M,$lamda,$mu,$t,$lamda_e,
                                   $ai_src,$a_intend,$a_offer,$rho,
                                   $enq,$ens,$eqt,$est,$eqtq,$eqt_a,$est_a,$eqtq_a,
                                   $pq,$pq_a,$pqt,$pqt_a,$pst,$pst_a,$pqtq,$pqtq_a,
                                   $p_sum,$p_sum_a,\@pstate,\@pstate_a);
    push @out_records,@$out_record_ref;

    ################################
    # Create Trace Data - opt_t    #
    ################################
    if($opt_t)
    {
      ($trace_ref) = trace($daydatetime,$c,$N,$lamda,$mu,$rho,
                           $p0_t1,$p0_t2,$p0_t3,$pzero,
                           $p0_t1_a,$p0_t2_a,$p0_t3_a,$pzero_a,
                           $pstate_0_c_ref,$pn_0_c,$pstate_0_c_a_ref,$pn_0_c_a,
                           $pstate_c_N_ref,$pn_c_N,$pstate_c_N_a_ref,$pn_c_N_a,
                           $p_sum,$p_sum_a);
      push @traces,@$trace_ref;
    }

    ################################
    # Undef Variables              #
    ################################
    undef $pn_0_c;
    undef $pn_0_c_a;
    undef $pn_c_N;
    undef $pn_c_N_a;
    undef @pstate;
    undef @pstate_a;
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
  my($ai_src,$c,$N) = @_;

  my($i);

  my($term1)=1;
  my($term2)=$N;
  my($term3)=1;
  my($ii)=1;
  my($p0_t1)=1;

  ################################
  # Calculate denom              #
  ################################
  for($i=0;$i<$c-1;$i++)
  {
    $term2 = $N-$i;
    $term1=$term1*$term2;
    $ii = $ii*($i+1);
    $term3=$term3*$ai_src;
    $p0_t1 += $term1/$ii*$term3;
  }
  return($p0_t1);
}


sub
p0_t2
{
  my($ai_src,$c,$N) = @_;

  my($j);
  my($p0_t2);

  my($term1)=1;

  ################################
  # Calculate p(zero) - p0_t2    #
  ################################
  for($j=0;$j<$N-$c;$j++)
  {
    $term1=$term1*($N-$j)/($N-$c-$j);
  }
  for($j=0;$j<$c;$j++)
  {
    $term1=$term1*$ai_src;
  }
  $p0_t2=$term1;

  return($p0_t2);
}


sub
p0_t3
{
  my($ai_src,$c,$N,$p0_t2) = @_;

  my($j);
  my($p0_t3);
  my($term1);

  ################################
  # Calculate p(zero) - p0_t3    #
  ################################
  $p0_t3=$p0_t2;
  $term1=$p0_t3;
  for($j=0;$j<$N-$c;$j++)
  {
    $term1=$term1*($N-$c-$j)*$ai_src/$c;
    $p0_t3 += $term1;
  }

  return($p0_t3);
}


sub
pn_0_c
{
  my($ai_src,$c,$N,$pzero) = @_;

  my($i);
  my($term4);
  my(@pstate_0_c);

  my($term1)=1;
  my($term2)=$N;
  my($term3)=1;
  my($ii)=1;
  my($p0_t1)=1;

  ################################
  # Calculate p(n) - pn_0_c      #
  ################################
  $pstate_0_c[0]=$pzero;
  for($i=0;$i<$c-1;$i++)
  {
    $term2 = $N-$i;
    $term1 = $term1*$term2;
    $ii = $ii*($i+1);
    $term3 = $term3*$ai_src;
    $term4 = $term1/$ii*$term3;
    $pstate_0_c[$i+1] = $term4*$pstate_0_c[0];
  }
  return(\@pstate_0_c);
}


sub
pn_c_N
{
  my($ai_src,$c,$N,$p0_t2,$pzero) = @_;

  my($j);
  my(@pstate_c_N);
  my($term1);

  ################################
  # Calculate p(n) - pn_c_N      #
  ################################
  $pstate_c_N[0]=$p0_t2*$pzero;
  $term1=$p0_t2;
  for($j=0;$j<$N-$c;$j++)
  {
    $term1 = $term1*($N-$c-$j)*$ai_src/$c;
    $pstate_c_N[$j+1] = $term1*$pzero;
  }

  return(\@pstate_c_N);
}


sub
pqt
{
  my($c,$N,$mu,$t,$pstate_ref) = @_;

  my($i);
  my($j);
  my($term1);
  my($sum1);
  my($pqt);

  ################################
  # Initialize Variables         #
  ################################
  $sum1 = $pstate_ref->[$c];

  ################################
  # Calculate sums               #
  ################################
  for($j=1;$j<$N-$c;$j++)
  {
    $term1 = $pstate_ref->[$j+$c];
    $sum1 = $sum1+$term1;

    for($i=1;$i<=$j;$i++)
    {
      $term1 = $term1*$c*$mu*$t/$i;
      $sum1 = $sum1+$term1;
    }
  }

  ################################
  # Calculate pqt                #
  ################################
  $pqt = $sum1/exp($c*$mu*$t); 

  return($pqt);
}


sub
pst
{
  my($c,$N,$mu,$t,$pq,$pstate_ref) = @_;

  my($i);
  my($j);
  my($term1);
  my($sum1);
  my($pst);

  ################################
  # Initialize Variables         #
  ################################
  $sum1=0;

  ################################
  # Calculate sums               #
  ################################
  for($j=$c;$j<$M;$j++)
  {
    $term1 = $pstate_ref->[$j];
    $sum1 = $sum1+$term1;

    for($i=1;$i<=$j;$i++)
    {
      $term1 = $term1*$c*$mu*$t/$i;
      $sum1 = $sum1+$term1;
    }
  }

  ################################
  # Calculate pst              #
  ################################
  $pst = (1-$pq)/exp($mu*$t)+$sum1/exp($c*$mu*$t); 

  return($pst);
}


sub
lamda_e
{
  my($N,$lamda,$pstate_ref) = @_;

  my($j);
  my($term1)=0;
  my($lamda_e)=$lamda/$N;

  ################################
  # Calculate lamda_e            #
  ################################
  for($j=0;$j<=$N;$j++)
  {
    $term1 += $j*$pstate_ref->[$N-$j]; 
  }
  $lamda_e = $lamda_e*$term1;

  return($lamda_e);
}


sub
enq_ens
{
  my($c,$N,$pstate_ref) = @_;

  my($j);
  my($enq)=0;
  my($ens)=0;

  ################################
  # Calculate enq                #
  ################################
  for($j=$c;$j<=$N;$j++)
  {
    $enq += ($j-$c)*$pstate_ref->[$j]; 
  }

  ################################
  # Calculate ens                #
  ################################
  for($j=0;$j<=$N;$j++)
  {
    $ens += $j*$pstate_ref->[$j]; 
  }

  return($enq,$ens);
}


sub
eqt_est_a
{
  my($c,$M,$mu,$pstate_a_ref) = @_;

  my($j);
  my($eqt_a)=0;
  my($est_a)=0;

  ################################
  # Calculate enq                #
  ################################
  for($j=0;$j<$M-$c;$j++)
  {
    $eqt_a += ($j+1)*$pstate_a_ref->[$j+$c]; 
  }
  $eqt_a = $eqt_a*1/($c*$mu);

  ################################
  # Calculate ens                #
  ################################
  $est_a = $eqt_a+(1/$mu); 

  return($eqt_a,$est_a);
}


sub
out_record
{
  my($daydatetime,$c,$N,$M,$lamda,$mu,$t,$lamda_e,
     $ai_src,$a_intend,$a_offer,$rho,
     $enq,$ens,$eqt,$est,$eqtq,$eqt_a,$est_a,$eqtq_a,
     $pq,$pq_a,$pqt,$pqt_a,$pst,$pst_a,$pqtq,$pqtq_a,
     $p_sum,$p_sum_a,$pstate_ref,$pstate_a_ref) = @_;

  my ($row);
  my ($record);
  my ($record_a);
  my (@out_record);
  my($j);

  #################
  # Results Data  #
  #################
  $row = "\nMMcN QueState Results: $daydatetime";
  push @out_record,$row;

  ######################################
  # Performance Statistics             #
  ######################################
  $row = join ',','c','N','lamda','mu','t','lamda_e','ai_src','a_intend',
                  'a_offer','rho','E(nq)','E(ns)';
  push @out_record,$row;
  $row = join ',',$c,$N,$lamda,$mu,$t,$lamda_e,$ai_src,$a_intend,
                  $a_offer,$rho,$enq,$ens;
  push @out_record,$row;
  $row = join ',','Statistics','E(qt)','E(st)','E(qt/q)',
                               'p[q]','p[q>t]','p[s>t]','p[q>t/q]','p_sum';
  push @out_record,$row;
  $row = join ',','Observer',$eqt,$est,$eqtq,
                             $pq,$pqt,$pst,$pqtq,$p_sum;
  push @out_record,$row;
  $row = join ',','Arrival',$eqt_a,$est_a,$eqtq_a,
                            $pq_a,$pqt_a,$pst_a,$pqtq_a,$p_sum_a;
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
  $record_a = join ',','Arrival';
  for($j=0;$j<=$N-1;$j++)
  {
    $record_a = join ',',$record_a,$pstate_a_ref->[$j];
  }
  push @out_record,$record_a;

  return(\@out_record)

}


sub
trace
{
  my($daydatetime,$c,$N,$lamda,$mu,$rho,
     $p0_t1,$p0_t2,$p0_t3,$pzero,
     $p0_t1_a,$p0_t2_a,$p0_t3_a,$pzero_a,
     $pstate_0_c_ref,$pn_0_c,$pstate_0_c_a_ref,$pn_0_c_a,
     $pstate_c_N_ref,$pn_c_N,$pstate_c_N_a_ref,$pn_c_N_a,
     $p_sum,$p_sum_a) =  @_;

  my ($row);
  my (@trace);
  my ($record);
  my ($j);

  ##############
  # Trace Date #
  ##############
  $row = "\nMMcN QueState Trace Data: $daydatetime";
  push @trace,$row;

  ######################################
  # Input Parameters                   #
  ######################################
  $row = join ' ',"c=$c","N=$N","lamda=$lamda","mu=$mu","rho=$rho";
  push @trace,$row;

  #####################################
  # Observer View                     #
  #####################################
  $j=0;
  $row = "Observer View";
  push @trace,$row;
  
  #####################################
  # p[0] - p0_t1 p0_t2 p0_t3 p(zero)  #
  #####################################
  $row = join ' ',"pzero=$pzero","p0_t1=$p0_t1",
                  "p0_t2=$p0_t2","p0_t3=$p0_t3";
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
  # p[n] - pn_c_N                #
  ################################
  foreach $record (@$pstate_c_N_ref)
  {
    $row = join '','pstate_c_N_val[',sprintf('%03d',$j++),']=',$record;
    push @trace,$row;
  }
  $row = join ' ',"pn_c_N=$pn_c_N";
  push @trace,$row;

  ################################
  # p_sum                        #
  ################################
  $row = join ' ',"p_sum=$p_sum";
  push @trace,$row;

  #####################################
  # Arrival View                      #
  #####################################
  $j=0;
  $row = "Arrival View";
  push @trace,$row;

  #####################################
  # p[0] - p0_t1 p0_t2 p0_t3 p(zero)  #
  #####################################
  $row = join ' ',"pzero_a=$pzero_a","p0_t1_a=$p0_t1_a",
                  "p0_t2_a=$p0_t2_a","p0_t3_a=$p0_t3_a";
  push @trace,$row;

  ################################
  # p[n] - pn_0_c                #
  ################################
  foreach $record (@$pstate_0_c_a_ref)
  {
    $row = join '','pstate_0_c_a_val[',sprintf('%03d',$j++),']=',$record;
    push @trace,$row;
  }
  $row = join ' ',"pn_0_c_a=$pn_0_c_a";
  push @trace,$row;

  ################################
  # p[n] - pn_c_N                #
  ################################
  foreach $record (@$pstate_c_N_a_ref)
  {
    $row = join '','pstate_c_N_a_val[',sprintf('%03d',$j++),']=',$record;
    push @trace,$row;
  }
  $row = join ' ',"pn_c_N_a=$pn_c_N_a";
  push @trace,$row;

  ################################
  # p_sum                        #
  ################################
  $row = join ' ',"p_sum_a=$p_sum_a";
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
