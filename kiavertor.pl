#!/usr/bin/env perl

use warnings;
use strict;
use Encode::Guess;
use Getopt::Long;
use Term::ANSIColor;
use Cwd;
use 5.012;

my @files;
our $rescount = 1;
my %opts = ( decodesource => 'auto' );

GetOptions(
    \%opts,
        "filesource|f=s@",
        "decodesource|s=s",
        "dirtarget|t=s",
        "encodetarget|e=s",
        "directory|d=s",
        "fileextension|x=s",
        "regex|r=s",
        "help|h",
);

# require opts
if ( !defined $opts{filesource} && !defined $opts{directory}
    || !defined $opts{encodetarget} )
{
    die usage();
}

# handle -h
print usage() && exit(0) if exists $opts{help};

if ( defined $opts{dirtarget} )
{
    $opts{dirtarget} =~ s:(.*):\Q$1\E:;
    if ( -d $opts{dirtarget} )
    {
        $opts{dirtarget} =~ s:/$::;
    } else
    {
        mkdir( $opts{dirtarget}, 0755 )
          || die colored( "...Failed to create $opts{dirtarget}: $!", 'red' ),
          "\n";
    }
}

if ( defined $opts{filesource} )
{
    for ( my $i = 0 ; $i < @{ $opts{filesource} } ; $i++ )
    {
        if ( !-f ${ $opts{filesource} }[$i] )
        {
            print colored(
                "...${ $opts{filesource} }[$i] is not valid file name", 'red'
              ),
              "\n";
        } elsif ( -f ${ $opts{filesource} }[$i] ) {
            push @files, ( ${ $opts{filesource} }[$i] );
        }
    }
}

#  $direct =~ s:(.*):\Q$1\E:;
my $directcwd = cwd;

#  $directcwd = "\Q$directcwd\E";
$opts{directory} = $directcwd
  if ( defined $opts{directory} && $opts{directory} eq "here" );

if ( defined $opts{directory} && -d $opts{directory} )
{
    $opts{directory} =~ s:/$::;

    #$opts{directory} =~ s: :\\ :;
    $opts{directory} =~ s:(.*):\Q$1\E:;    #s:(\W):\\$1:g;
    my @fd;

    if ( defined $opts{fileextension} )
    {
        @fd = glob("$opts{directory}/*.$opts{fileextension}");
    } else
    {
        @fd = glob("$opts{directory}/*");
    }

    if ( defined $opts{regex} )
    {
        @fd = grep( /$opts{regex}/, @fd );
    }

    foreach (@fd)
    {
        push @files, ($_) if ( !-d $_ );
    }
}

foreach my $filesource (@files)
{
    if ( $opts{decodesource} eq "auto" )
    {
        open( FILE, $filesource )
          || die colored( "...cannot open input file: $!", 'red' ), "\n";
        binmode(FILE);

        if ( read( FILE, my $filestart, 500 ) )
        {
            my $enc = guess_encoding($filestart);
            if ( ref($enc) )
            {
                kiavert( $filesource, $enc->name );
            } else
            {
                print colored(
                    "...Encoding of file $filesource can't be guessed", 'red'
                  ),
                  "\n";
            }
        } else
        {
            print colored( "...Cannot read from file $filesource", 'red' ),
              "\n";
        }
        close(FILE);
    } else
    {
        kiavert( $filesource, $opts{decodesource} );
    }
}

sub kiavert {
    my ( $inputfile, $inputbin ) = @_;
    my $outputfile;
    if ( defined $opts{dirtarget} and -d $opts{dirtarget} )
    {
        my $infn = $inputfile;
        $infn =~ s:.*/(.*)$:$1:;
        $outputfile = "$opts{dirtarget}/$infn-$opts{encodetarget}";
    } else
    {
        $outputfile = "$inputfile-$opts{encodetarget}";
    }

    my $num = 1;
    while (-e $outputfile)
    {
        my $tfi = $outputfile;
        $tfi .= "-$num";
        ($outputfile = $tfi) if not -e $tfi;
        ++$num;
    }

    my $file_content;
    {
        open( my $INPFI, "<:encoding($inputbin)", $inputfile )
        || die colored( "...cannot open input file: $!", 'red' ), "\n";
        local $/ = undef;
        $file_content = <$INPFI>;
        close($INPFI);
    }

    open( my $OUPFI, ">:encoding($opts{encodetarget})", $outputfile )
      || die colored( "...cannot creat output file: $!", 'red' ), "\n";
    print $OUPFI $file_content;
    close($OUPFI);

    print colored(
        "[$rescount] + $inputbin > $opts{encodetarget} .... $outputfile",
        'green'
      ),
      "\n";
    $rescount++;
}

sub usage {
    my $pnm = $0;
    $pnm =~ s".*/(.*)"$1";
    return <<EOHIPPUS;
$pnm -f FILENAME -e TARGETENCODING [OPTIONS...]
one of <-f or -d> and -e must set
Options:
--help or -h
	this help
-f /path/file
	input file name
	can use multiple -f
-s DECODING		ex: -s windows-1256
	file(s) source encoding
	if dont use -s, file encoding determine automaticly if possible
-e ENCODING 	ex: -e utf-8
	file target encoding
-t /copy/new/file_s/in_this/path/
	dir path for new files
-d /path/
|	choose all file in a directory
|
v
[Dir mode]
-d here
	if use [-d here] use current path that you run $pnm from
-x EXTENSION       ex: -x txt
	if use -d then you can choose all files with same extensions in your path
--regex="REGEX" or -r "REGEX"
	choose file(s) name with your pattern
	DIR mode ex: -d here -r "^\\d\-\\w+(_flm)" -x srt
new file name is /path/file-encodetarget
EOHIPPUS
}
