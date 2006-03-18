package Yahoo::Music::Ratings;

use LWP::UserAgent;
use XML::Simple;
use strict;
use warnings;

require Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Yahoo::Music::Ratings ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '1.00';


# Preloaded methods go here.

sub new {
    my $class = shift;
    my $this = bless {}, $class;
    
    # Set sessions options
    $this->{options} = shift;
    
    print "Yahoo::Music::Ratings Progress Output Enabled\n" . '-' x 80 . "\n" if $this->{options}->{progress};
    
    return $this;
}

sub findMemberId {
    my $this = shift;
    
    unless ( $this->{memberid} ){
        my $ua = LWP::UserAgent->new;
        $ua->timeout(10);
        $ua->env_proxy;
        
        $ua->max_redirect(0);
        
        my $response = $ua->get('http://music.yahoo.com/launchcast/membersearch.asp?memberName='.$this->{options}->{memberName} );
        
        if ($response->is_success) {
            #print $response->status_line;
            print "$this->{errorMessage}\n" if $this->{options}->{progress};
            $this->{errorMessage} = "Looks like either Yahoo is down or they've changed their site which means this module no longer works. Sorry :(";
            return( 0 );
        }
        else {
            ($this->{memberid}) = $response->header('Location') =~ m/station\.asp\?u=(\d+)/g;
            print "Searched for $this->{options}->{memberName}'s memberId: $this->{memberid}\n" if $this->{options}->{progress};
            return( $this->{memberid} );    
        }
    }
}

sub getRatings {
    my $this = shift;
    
    # check to see if we have a memberId for this user,
    # if not fetch one
    unless ( $this->{memberid} ){
        unless ( $this->findMemberId() ){
            # if we were unable to fetch a memberId then return negativly
            # User should check $foo->error_message() for errors
            return( 0 );
        }
    }
    
    print "Loading Ratings Pages\n" if $this->{options}->{progress};
    if ( $this->_parseRatings( 0 ) ){
        for(my $i=1; $i < $this->{totalPages}; $i++){
            $this->_parseRatings( $i );
        }
        
        return( $this->{data} );
    }
    else {
        return( 0 );
    }
     
}

sub _parseRatings {
    my $this = shift;
    my $page = shift;
    
    my $xs = new XML::Simple();
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->env_proxy;
    
    my $response = $ua->get('http://yme.us.music.yahoo.com/profile/rating_xml.asp?type=1&uid='. $this->{memberid} .'&p='. $page .'&g=undefined&gt=1');
    
    if ($response->is_success) {
        my $ref = $xs->XMLin( $response->content );

        $this->{totalPages} = $ref->{SONG_RATINGS}->{SONG_RATING_LIST}->{POSITION}->{PAGES}->{TOTAL};
    	$this->{currentPage} = $ref->{SONG_RATINGS}->{SONG_RATING_LIST}->{POSITION}->{PAGES}->{CURRENT};
        print "$this->{currentPage} of $this->{totalPages}\n" if $this->{options}->{progress};
    
        foreach my $elem (@{$ref->{SONG_RATINGS}->{SONG_RATING_LIST}->{LIST}->{LIST_ROW}}) {
            #  {
            #	'VIEWER_RATING' => {
            #					   'VALUE' => '-1'
            #					 },
            #	'SONG' => {
            #			  'ID' => '319952',
            #			  'ALBUM' => {
            #						 'ID' => '115213',
            #						 'NAME' => 'The Slim Shady LP (Edited)'
            #					   },
            #			  'NAME' => 'My Name Is',
            #			  'HAS_SAMPLE' => {},
            #			  'ARTIST' => {
            #						  'ID' => '289114',
            #						  'NAME' => 'Eminem'
            #						},
            #			  'HAS_TETHDOWNLOAD' => {},
            #			  'HAS_ODSTREAM' => {},
            #			  'HAS_PERMDOWNLOAD' => {}
            #			},
            #	'USER_RATING' => {
            #					 'VALUE' => '100'
            #				   }
            #  },
            
            push(@{$this->{data}}, [
                         $elem->{SONG}->{ARTIST}->{NAME},
                         $elem->{SONG}->{NAME},
                         $elem->{SONG}->{ALBUM}->{NAME},
                         $elem->{USER_RATING}->{VALUE},
                         ]);
        }
        
        return( 1 );
    }
    else {
        $this->{errorMessage} = "Looks like either Yahoo is down or they've changed their site which means this module no longer works. Sorry :(";
        print "$this->{errorMessage}\n" if $this->{options}->{progress};
        return( 0 );
    }
}

sub tab_output {
    my $this = shift;
    
    my @tabbed;
    
    foreach my $row (sort {uc($a->[0]) cmp uc($b->[0])} @{$this->{data}}){
        push(@tabbed, join("\t", @{$row} ) );
    }
    
    my $tabbed = join("\n", @tabbed);
    undef(@tabbed);
    return( $tabbed );
}

sub error_message {
    my $this = shift;
    return( $this->{errorMessage} );
}


1;
__END__

=head1 NAME

Yahoo::Music::Ratings - A method for retrieving a Yahoo! Music
members song ratings.

=head1 SYNOPSIS

    use Yahoo::Music::Ratings;
    
    my $ratings = new Yahoo::Music::Ratings( { 
				memberName => 'yahooMusicMemberName',
		} );
    
    # Fetch an arrayRef of all yahooMusicMemberName song ratings
    # this may take a couple minutes...
    my $arrayRef = $ratings->getRatings();
    
    # Print out a nice tab seperated version so that we can easily
    # read the list in a spreadsheet program (and then filter by
    # artists etc). tab_output() will output in artists alphabetical
    # order.
    print $ratings->tab_output();

=head1 DESCRIPTION

This module provides a way to retrieve a user's list of song ratings 
from Yahoo!'s Music service, including the LaunchCast and 
Unliminted services.

As Yahoo! do not provide an offical feed for a member to download
their ratings, the methods used within this module are subject to
change and simply may not work tomorrow. However at the time of 
writing this README i would suspect the methods used should be
stable for atleast a few days :)

=head1 METHODS

=head2 new( $hashref )
	
new() expects to find a hashref with a key and value of 
C<memberName> (Yahoo Music! Member Name).

    my $ratings = new Yahoo::Music::Ratings( { 
        memberName => 'smolarek', 
        progress => 0 
       } );

Providing a true value to the optional C<progress> argument will give you
a simple progress report printed to STDOUT.

returns an object reference

=head2 getRatings

No arguments are required.

Fetches a members song listing. This function will need to make
several calls to the Yahoo! Music site and therefore may take upto
a few minutes on a slow connection.

    my $arrayRef = $ratings->getRatings();

getRatings() will retun 0 if a problem was encountered or an arreyRef
if everything worked as planned. The arrayRef contains a 3d array of
ratings.

Example output:
    
    [
        'Red Hot Chili Peppers',    # Artist
        'Under The Bridge',         # Song
        'Blood Sugar Sex Magik',    # Album
        '100'                       # Member Song Rating 
    ],

=head2 tab_output [optional]

No arguments required.

You I<must> call C<getRatings()> prior to using this function.

Will return a large string containing a tab seperated value of
ratings requested previously in artist alphabetical order. Simply 
pipe this string to a file and open in a spreadsheet application for
easy filtering and readability. If an error has been detected, 
will return 0.

Example

    The Police	Every Breath You Take	Synchronicity	90
    Van Morrison	Brown Eyed Girl	Blowin' Your Mind!	90


=head2 error_message [optional]

If any previous function returns 0 you can call C<error_message()>
to get a descriptive error message.

Returns a string with the error.

=head2 findMemberId [optional]

To get a member's player ratings we need to convert the memberName
into a memberId (bigint). This ID servers little other purpose,
however should you wish to retain this ID or to seak for several
different member ID's without further need to query the ratings
then simply exectute this function without arguments.

returns an int

=head1 EXPORT

None by default.


=head1 SEE ALSO

B<Yahoo::Music::Ratings> requires L<XML::Simple> or L<LWP::UserAgent>.

=head1 AUTHOR

Pierre Smolarek <lt>pierre@smolarek.com<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Pierre Smolarek

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
