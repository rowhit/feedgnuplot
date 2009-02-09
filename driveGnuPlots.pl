#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use Data::Dumper;

# stream in the data by default
# point plotting by default
my %options = ( "stream" => 1,
                "lines" => 0);

GetOptions(\%options,
           "stream!",
           "lines!");

# set up plotting style
my $style = "points";
$style = "linespoints" if($options{"lines"});

sub usage {
    print "Usage: $0 <options>\n";
    print <<OEF;
where mandatory options are (in order):

  NumberOfStreams                       How many streams to plot
  Stream_WindowSampleSize               this many samples
  Stream_YRangeMin Stream_YRangeMax     Min and Max y values

OEF
    exit(1);
}

sub Arg {
    if ($#ARGV < $_[0]) {
        print "Expected parameter missing...\n\n";
        usage;
    }
    $ARGV[int($_[0])];
}

sub main {
    my $argIdx = 0;
    my $numberOfStreams = Arg($argIdx++);
    print "Will display $numberOfStreams Streams...\n";

    my $samples = Arg($argIdx++);
    print "Will use a window of $samples samples\n";

    my $miny = Arg($argIdx++);
    my $maxy = Arg($argIdx++);
    print "Will use a range of [$miny, $maxy]\n";

    my @buffers;
    shift @ARGV; # number of streams
    shift @ARGV; # sample size
    shift @ARGV; # miny
    shift @ARGV; # maxy
    local *PIPE;

    open PIPE, "|gnuplot" || die "Can't initialize gnuplot\n";

    select((select(PIPE), $| = 1)[0]);
    print PIPE "set xtics\n";
    print PIPE "set ytics\n";
    print PIPE "set yrange [". $miny . ":" . $maxy ."]\n";
    print PIPE "set style data $style\n";
    print PIPE "set grid\n";

    for(my $i=0; $i<$numberOfStreams; $i++) {
      push @buffers, [];
    }

    my $streamIdx = 0;
    select((select(STDOUT), $| = 1)[0]);
    my $xlast = 0;
    while(<>)
    {
      chomp;
      my $line = $_;
      foreach my $point ($line =~ /([-]?[0-9\.]+)/g) {
        my $buf = $buffers[$streamIdx];

        # data buffering (up to stream sample size)
        push @{$buf}, $point;
        shift @{$buf} if(@{$buf} > $samples && $options{"stream"});

        $streamIdx++;
        if ($streamIdx == $numberOfStreams) {
          $streamIdx = 0;
          plotStoredData($xlast, $samples, $numberOfStreams, *PIPE, \@buffers) if($options{"stream"});
          $xlast++;
        }
      }
    }

    if($options{"stream"})
    {
      print PIPE "exit;\n";
      close PIPE;
    }
    else
    {
      $samples = @{$buffers[0]};
      plotStoredData($xlast, $samples, $numberOfStreams, *PIPE, \@buffers);
    }
    sleep 100000;
}

sub plotStoredData
{
  my ($xlast, $samples, $numberOfStreams, $pipe, $buffers) = @_;

  my $x0 = $xlast - $samples + 1;
  print $pipe "set xrange [$x0:$xlast]\n";
  print $pipe 'plot ' . join(', ' , ('"-" notitle') x $numberOfStreams) . "\n";

  foreach my $buf (@{$buffers})
  {
    # if the buffer isn't yet complete, skip the appropriate number of points
    my $x = $x0 + $samples - @{$buf};
    for my $elem (@{$buf}) {
      print $pipe "$x $elem\n";
      $x++;
    }
    print PIPE "e\n";
  }
}


main;
