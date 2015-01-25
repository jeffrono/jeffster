&configVals;
$totalSongCount = 0;
open(DEBUG, ">>debug.txt");

# make the directory
$songDirectory = $destinationDirectory . "songList\\";
mkdir($songDirectory , 0777);
print DEBUG "made directory $songDirectory \n";

open(JOE, "c:\\songList.txt");
while(<JOE>) {
	$songName = $_;
	print "$songName";
	$totalSongCount++;
	&enqueueSong;
	&addToQueue;
}

#####################################
# subroutine to enqueue a song given $artist, $songName and $SID, gives $MP3Title
#####################################

sub enqueueSong {
	do {
	$isInEnqueue = 0;
	$URL = "http://www.audiogalaxy.com/list/searches.php?SID=" . $SID . "&searchType=0&searchStr=" .  $artist . " " . $songName;
	$_ = get($URL);
	
	# choose the best ranking song from the list of search results
	if (/4_0.gif[^\?]+\?SID=$SID&g=([\d]+)/) {
		$songID = $1;
		$errorMark = 4;
	}
	elsif (/3_0.gif[^\?]+\?SID=$SID&g=([\d]+)/) {
		$songID = $1;
		$errorMark = 3;
	}
	elsif (/2_0.gif[^\?]+\?SID=$SID&g=([\d]+)/) {
		$songID = $1;
		$errorMark = 2;
	}
	elsif(length($_) != 0) {
		$outputError = ">>" . $directory . "errors.csv";
		open(ERRORS, $outputError);
		print ERRORS "$songName,$artist,$albumDirectoryName,";
		if (/1_0.gif[^\?]+\?SID=$SID&g=/) { print ERRORS "1\n"; }
		elsif (/broadening your search/) { print ERRORS "xxx\n"; }
		else { print ERRORS "0\n"; }
		close(ERRORS);
		$MP3Title = "";
		$errorMark = 1;
	}

	print DEBUG "found song... ID = $songID, ranking = $errorMark\n";

	$URL = "http://www.audiogalaxy.com/list/song.php?&g=" . $songID;
	print DEBUG "getting URL\n";
	$_ = get($URL);
	sleep 5;
	$_ = get($URL);
	s/\\/\-/gi;
	if (/#FFFFFF;\">([^<]+)<\/span>([^<]+)<\/span>/ && $errorMark != 1) {
		print DEBUG "found the song in html\n";
		$songCount++;
		$totalSongCount++;
		print DEBUG "song count now = $songCount\n";
		$songCheck = $2;
		$MP3Title = $1 . $2 . ".mp3";
		$MP3Title =~ tr/[:\*\?\"|]/\-/;
		$URL = "http://www.audiogalaxy.com/satellite/queue.php?g=" . $songID. "&SID=" . $SID;
		print DEBUG "getting $URL\n";
		get($URL);
		sleep 5;
		get($URL);
		sleep 5;
		get($URL);

		if(/$songCheck/) {
			$isInEnqueue = 1;
			print DEBUG "$songCheck was found in html, and isinEnqueue is one\n";
		}
		
	} # if it finds the song, and it is in the enqueue
	
	if($isInEnqueue == 0 && $errorMark != 1) {
		print DEBUG "couldnt find song in html, so its still not in the enqueue\n";
		$songCount--;
		$totalSongCount--;
		print ".";
		
	} # if not in enqueue, wait
	
	} # do loop
	until ($isInEnqueue == 1 || $errorMark == 1);
	print "Rank: $errorMark\n";
	print DEBUG "song was enqueued and is ranked $errorMark\n";
}

#####################################
# subroutine to get the name of the artist at the top of the text list of artists
#####################################

sub getArtist {
	$input = $directory . "artistList.txt";
	open(ARTISTLIST, $input);
	@artistList = ();
	$i = 0;
	while (<ARTISTLIST>) {
		s/\n//;
		$artistList[$i] = $_;
		$i++;
	}
	close(ARTISTLIST);
	$_ = $artistList[0];
		
	# if it's an artist/album combo
	if (/>/) {
		/([^>]+) > ([^\n]+)/;
		$artist = $1;
		$album = $2;
		$isAlbum = 1;
		print DEBUG "downloading $artist - $album\n";
		print "Downloading: $artist - $album\n";
	} # if artist/album, $album gets assigned

	else {
		$artist = $_;
		$isAlbum = 0;
		print "Downloading all albums by: $artist --> ";
	}
}

#####################################
# delete the top artist from the list of artists
#####################################

sub deleteArtist {
	$output = ">" . $input;
	open(ARTISTLIST, $output);
	for ($i = 1; $i <= $#artistList; $i++) {
		print ARTISTLIST $artistList[$i] . "\n";
	}
	close(ARTISTLIST);
}

#####################################
# subroutine to retrieve album data for a given artist from CDnow.com
# and given a artist/album combo, 
#####################################

# outputs 2D array:
# [number of albums]
# [artist]
# [title of album1 2 0] [title of album2 2 1] ...
# [track 1 - 3 0]         	[track 1]
# [track 2]         	[track 2]...

sub getAlbumInfo {
	use LWP::Simple;
if ($artist ne "") {
	$URL = "http://www.cdnow.com/cgi-bin/mserver/SID=1188262721/pagename=/RP/CDN/FIND/popsearch.html/clickID=tn_srch_txt/string=" . $artist;
	$_ = get($URL);
	$artist2 = $artist;
	if (/\/ArtistID=([^\"]+)\">([^<]+)</) {
		$webArtist = $1;
		$artist = $2;
		#print "$artist\n";
		
		#get discography of artist
		$URL = "http://www.cdnow.com/cgi-bin/mserver/SID=1505816878/pagename=/RP/CDN/FIND/discography.html/ArtistID=" .  $webArtist;
		$_ = get($URL);
	}
	
	s/[\w\W]+(<B>ALBUMS[\w\W]+)<B>IMPORT ALBUMS[\w\W]+/$1/gi;
	s/(<B>ALBUMS[\w\W]+)<B>SINGLES[\w\W]+/$1/gi;
	s/(<B>ALBUMS[\w\W]+)<B>COMPILATIONS[\w\W]+/$1/gi;
	s/\\/\-/gi;
	
	$albumIndex = 0;
	@albumTitleURL = ();
	@albumArray = ();
	
	# if downloading all albums
	if ($isAlbum == 0) {
		# make ARRAY of URLs of albums	
		while(/href="([^"]+)">([^<]+)</gm) {
			$possibleURL = $1;
			if ($possibleURL =~ /itemid/) {
				$albumTitleURL[$albumIndex] = "http://www.cdnow.com" . $possibleURL;
				$albumIndex += 1;
			}
		}
	} # if for ALL albums
	
	else {
		/href="([^"]+)">$album</igm;
		$albumTitleURL[$albumIndex] = "http://www.cdnow.com" . $1;
	}

	# if any albums exist
	if ($albumIndex > 0) {
		print "$albumIndex Albums Found!\n";
		# download ALBUM information and put into an ARRAY
		$numberOfAlbums = 0;
		$albumArray[1][0] = $artist;
		foreach $URL (@albumTitleURL) {
			$_ = get($URL);
			$lineNumber = 2;
			
			# get title of album
			/:\s+([^:]+)\s+:\s+tracks/gm;
			$titleOfAlbum = $1;
			$titleOfAlbum =~ tr/[:\*\?\"|]/\-/;
			$albumArray[$lineNumber][$numberOfAlbums] = $titleOfAlbum;	
			print "****  $albumArray[$lineNumber][$numberOfAlbums]  ***\n";
			$lineNumber++;
	
			if(/COLOR="#333333"><b>[^<]+</) {
				while (/COLOR="#333333"><b>([^<]+)</gm) {
					$albumArray[$lineNumber][$numberOfAlbums] = $1;
					$lineNumber++;
				} # while there are more tracks
			$numberOfAlbums++;
			} # if there are tracks
		
		} #foreach
		$albumArray[0][0] = ($numberOfAlbums - 2);
	} # if albumindex > 0
	
} #end if
} # end of SUB > getAlbumInfo

#####################################
# subroutine to print the list of album titles (to be used in later version)
#####################################

sub printTitles {
	open(INFO, ">>" . $directory . "info.txt");
	for ($i = 0; $i < $numberOfAlbums; $i++) {
		print INFO "** $artist - $albumArray[2][$i] *********\n";
		$j = 3;
		while ($albumArray[$j][$i] ne "") {
			print INFO $j-2 . " - $albumArray[$j][$i]\n";
			$j += 1;
		}
	}
	close(INFO);
}

#####################################
# subroutine to append an MP3Title to "Queue.txt"
# given $albumDirectoryName, $MP3Title
#####################################

sub addToQueue {
	$output2 = ">>" . $directory . "Queue.txt";
	open(BATFILE, $output2);
	foreach $temp (@playList) {
		if (length($temp) > 3) {
			print BATFILE $temp . "<s>". $albumDirectoryName . "<d> d\n";
			print DEBUG "batfile: $albumDirectoryName $temp\n";
			}
	}
	close(BATFILE);
}

#####################################
# read in Config.txt for vals
#####################################

sub configVals {
	open(CONFIG, "<config.txt");
	while (<CONFIG>) {
		if (/Home Directory: ([\w\W]+) \#/) { $directory = $1; }
		if (/Destination Directory: ([\w\W]+) \#/) { $destinationDirectory = $1; }
		if (/Download Directory: ([\w\W]+) \#/) { $downloadDir = $1; }
		if (/SID: ([\w\W]+) \#/) { $SID = $1; }
	}
	close(CONFIG);
	
	print "$directory\n";
	print "$destinationDirectory\n";
	print "$downloadDir\n";
	print "$SID\n";
}