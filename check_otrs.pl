#!/usr/bin/perl -w

#Script zur Anzeige neuer Tickets, noch nicht bearbeiteter Tickets in OTRS
#Copyright (c) 2008 by Michael Glaess


use strict;
use Getopt::Long;
use vars qw($opt_t $opt_q $opt_c $opt_w $opt_v $opt_h);
my(%ERRORS) = ( OK=>0, WARNING=>1, CRITICAL=>2, UNKNOWN=>3, WARN=>1, CRIT=>2 );
use DBI;
use DBD::mysql;
use Net::SMTP;
sub print_help();

my $VERSION ="1.0";
my $DBuser;
my $DBpass;
my $DBname;
my $DBhost;
my $opt_v;
my $opt_h;
my $opt_w;
my $opt_c;
my $opt_t;      #0=Neue Tickets;1=offene Tickets
my $opt_q;      #3=Queue Servicehotline
my $status  ="0";
my $anzahl;
my $sql;
my $result;
my $message;

sub check_otrs {
#Check DatabaseConnection
my $dbhm=DBI->connect("dbi:mysql:$DBname:$DBhost","$DBuser","$DBpass",
    {
    PrintError=>1,
    }
);
unless ( $dbhm ) {
    die("No Connection to Database");
    }
my $dbhm2=DBI->connect("dbi:mysql:$DBname:$DBhost","$DBuser","$DBpass",
    {
    PrintError=>1,
    }
);


if ( $opt_t == "0" ) {
    # New Tickets
    #$sql = "Select count(*) as Anzahl from ticket where queue_id='".$opt_q."' and ticket_state_id='1'";    
    $sql = "Select count(*) as Anzahl from ticket where ticket_state_id='1'";    
    
} elsif ( $opt_t == "1" ) {
     # Open Tickets
     #$sql = "Select count(*) as Anzahl from ticket where queue_id='".$opt_q."' and ticket_state_id='4'";    
     $sql = "Select count(*) as Anzahl from ticket where ticket_state_id='4'";    
}

my $sqlp=$dbhm->prepare($sql);
if (!$sqlp->execute()){
    print "CRITICAL - Unable to Execute SQL-Query";
    $status = $ERRORS{'CRITICAL'};
    }    
$result=$sqlp->fetchrow_hashref();
#Set Optimize Text for Nagios
    $anzahl=$result->{Anzahl};
    $message = "Anzahl ";               #Count
    if ( $opt_t == "0" )
        {$message .= "neuer ";}         #New
    if ( $opt_t == "1" )
        {$message .="offener ";}        #Open

    $message = $message."Tickets: $result->{Anzahl}";

if    ($anzahl >= $opt_c) 
        {$status = $ERRORS{'CRITICAL'};}
elsif ($anzahl >= $opt_w) 
        {$status = $ERRORS{'WARNING'};}
else { $status = $ERRORS{'OK'};}


$sqlp->finish();

}
####################################


sub print_help () {
    printf "$0 plugin for Nagios check for new or open Tickets in OTRS\n";
    printf "Copyright (c) 2008 Michael Glaess\n";
    printf "Usage:\n";
    printf "   -q (--queue)  Queue: Default: 3 entspricht Servicehotline\n";
    printf "   -t (--type)   Type:  Default: 0 entspricht Neue Tickets\n";
    printf "   -w (--warn)   Warning-Level, Default: 0\n";
    printf "   -c (--crit)   Criticle-Level, Default: 2\n\n";
    printf "   -H (--host)   IP or FQDN of mysql host\n";
    printf "   -u (--user)   User of mysql database\n";
    printf "   -p (--pass)   Password to mysql database\n";
    printf "   -n (--dbname) Database name\n";
    printf "   -v            Version\n";
    printf "   -h (--help)   Help\n";
    printf "\n";
    print_usage();    
}
##############################################
sub print_usage () {
        print "Usage: $0 \n";
        print "       $0 -w 2 -c 3\n";
        print "       $0 -t 1 -q 3 -w 2 -c 4\n";
}
###############################################
$ENV{'BASH_ENV'}=''; 
$ENV{'ENV'}='';

Getopt::Long::Configure('bundling');
GetOptions
        ("v" => \$opt_v, "version"      => \$opt_v,
         "h" => \$opt_h, "help"         => \$opt_h,
         "q:i" => \$opt_q, "queue"      => \$opt_q,
         "t:i" => \$opt_t, "type"       => \$opt_t,
         "w:i" => \$opt_w, "warn"       => \$opt_w,
         "c:i" => \$opt_c, "crit"       => \$opt_c,

         "H:s" => \$DBhost, "host"      => \$DBhost,
         "u:s" => \$DBuser, "user"      => \$DBuser,
         "p:s" => \$DBpass, "pass"      => \$DBpass,
         "n:s" => \$DBname, "dbname"    => \$DBname );

#Set default Values
if ( !$opt_t){$opt_t=0;} #Just new Tickets
if ( !$opt_w){$opt_w=1;} #Warning at just one ticket
if ( !$opt_c){$opt_c=2;} #Set Critical even on two tickets
if ( !$opt_q){$opt_q=3;} #Default QUEUE -> Needs to Change!!

if (!$DBhost && !$DBuser && !$DBpass %% !$DBname){
        print_help();
        exit $ERRORS{'One of parametr about database is not set.'}; 
}

#printf "OPT_t = $opt_t,OPT_w= $opt_w, OPT_c = $opt_c, OPT_q = $opt_q\n";
if ($opt_v) {
        print "$0: $VERSION\n" ;
        exit $ERRORS{'OK'};
}
if ($opt_h) {print_help(); exit $ERRORS{'OK'};}

$status = $ERRORS{OK}; $message = '';

#Call CheckUp Routine
check_otrs;

#Give System a feedback what have we done
if( $message ) {
        if( $status == $ERRORS{OK} ) {
                print "OK: ";
        } elsif( $status == $ERRORS{WARNING} ) {
                print "WARNING: ";
        } elsif( $status == $ERRORS{CRITICAL} ) {
                print "CRITICAL: ";
        }
        print "$message\n";
} else {
        $status = $ERRORS{UNKNOWN};
        print "No Data yet\n";
}
exit $status;
