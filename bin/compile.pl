#!/usr/bin/perl -w
#use strict ;
use File::Basename ;
use Cwd;

#flatten the path
$ARGV[0]  =~ s/\/[.]\//\//g ;
my $EXE=$ARGV[0];
my $project = $ARGV[1];
my $psrcdir="$project/src/$project";
my $bkuppsrcdir="$project/src.bkup";

my $pdir="$project/build";
my $subdir = basename(dirname($ARGV[0])) ;
#my $subdir = basename($ARGV[0]) ;
#if ($subdir eq "repair.sanity") { $subdir="sanity"; }
say("SUBDIR=$subdir [ $ARGV[0] ]") ;
my $project_list = "bugged-program.txt" ;

if (! -d "$bkuppsrcdir/$project"){
    execute("mkdir -p $bkuppsrcdir");
    execute("cp -r $psrcdir $bkuppsrcdir/");
}

sub say {
    my $msg = $_[0];
    print STDERR "|[$0]|: $msg \n" ;
}
sub execute 
{
    my $cmd = $_[0] ;
    my $res = system($cmd) >> 8 ;
    if ($res != 0)
    {
        print STDERR "Command '$cmd' failed: $!" ; 
        exit(-1);
        
    }
}
sub make
{
    
    my $owdir=getcwd;
    chdir $pdir or die "fail chdir $pdir: $!" ;
    my $e=basename($EXE) ;
    my $cwdir=getcwd;
    my $make="make ";
    say("Currently in '$cwdir'") ;
    my $compile="mkdir -p logs";
	system($compile);
    $compile="$make 2> logs/make.$e.log";
    say($compile);
    my $res = system($compile) >> 8 ;
    say("Result: $res") ;
    # Python is picky when it comes to coverage instrumentation
    
    if ($res != 0 && ($project =~ m/python/) && ($subdir =~ m/coverage/))
    {
        say("FAILED TO COMPILE PYTHON") ;
        say("TRYING AGAIN, THIS MIGHT TAKE AWHILE!") ;
        my $result = system("make clean &> /dev/null") >> 8 ;
        if ($result != 0)
        {
            my $remake = system("$make 2>1 > logs/make.$e.log") >> 8 ;
            if ($remake != 0) { say("DIDNT WORK, DYING"); exit 1 ; }
            else { say("WORKED!"); }
        }
        
    } 
    elsif ($res != 0)
    {
        exit 1;
    }
    chdir $owdir or die "fail chdir $owdir: $!" ;
    my $update="cp $project/$project $EXE";
    $res=system($update);


}
# We want to change /home/mkd5m/genprog-many-bugs/libtiff-A-B/sanity/repair.sanity.c into sanity

my $do_coverage = ($subdir =~ m/coverage/) ;
open(FILE, "<$project_list") ;
my @repair_only = <FILE> ;
chomp @repair_only ;
my %pfiles= map { $_, 1 } @repair_only ;
close(FILE) ;
my @all = () ;

say("find $subdir returns `find $subdir`");
foreach my $file (grep (! m/coverage[.]path/, `find $subdir -type f -name "*.[ch]*"`))
#say("find $project/src returns `find $project/src`");
#foreach my $file (grep (! m/coverage[.]path/, `find $project/src`))
{
    chomp $file ;
    if (-f $file && ! ($file =~ m/coverage[.]path/) && ! ($file =~ m/\.o$/) )
    {
	$file =~ s/^[^\/]*\/// ; #this gets rid of $project prepended dir
        push(@all, $file) ;
    }
}
my @coverage_only = () ;
foreach my $file (@all)
{
    chomp $file ;
    if (! exists($pfiles{$file}))
    {
        push(@coverage_only, $file)
    }
}
print "Coverage only: @coverage_only\n" ;
print "Repair files: @repair_only\n" ;
print "Allfiles: @all\n" ;
foreach my $file (@coverage_only)
{
    print "mv $project/$file $project/$file-temp\n" ;
    execute("mv $project/$file $project/$file-temp") ;

}
my @to_copy = $do_coverage? @all : @repair_only ;
say("to_copy : @to_copy");
say("copying from $subdir to $project");

foreach my $file(@to_copy)
{

   (-f "$subdir/$file") or die "Invalid file to copy: $subdir/$file" ;
   execute("cp $subdir/$file $project/$file") ;

}
#chdir $project or die "fail chdir $project: $!" ;
make () ;
#chdir ".." or die "failed chdir ..: $!" ;
foreach my $file (@coverage_only)
{
    print "mv $project/$file-temp $project/$file\n" ;
    execute("mv $project/$file-temp $project/$file") ;
}


