&configVals;
use LWP::Simple;
open(DEBUG, ">>debug.txt");

# for each artist
do {
	&getArtist;

	# make the ARTIST directory
	$artistDirectoryName = $destinationDirectory . $artist . "\\";
	$artistDirectoryName2 = $destinationDirectory . $artist;

	$URL = "http://www.audiogalaxy.com/list/searches.php?SID=" . $SID . "&searchType=0&searchStr=" .  $artist;
	$_ = get($URL);

	# enqueue number of songs
	$i = 0;
	$j = 0;
	@songID = ();
	/\"&r=(\d+)/;
	$artistID = $1;
	print "$artist - $artistID\n";
	$offset = 0;
do {
	$URL = "http://www.audiogalaxy.com/list/artistInfo.php?&r=" . $artistID . "&offset=" . $offset;
	$_ = get($URL);
	$gotonext = 0;

#open(TEMP, ">temp1.html");
#print TEMP $_;
#close (TEMP);
	$rank = 4;
	while(/(\d)_0.gif\"><\/td><td><td><a href=\/list\/song.php\?SID=[^&]+&g=(\d+)/g && $i < $sampleNumber && $rank > 1) {
		  #4_0.gif"></  td><td><td><a href=/ list/ song.php? SID=    &g=
		$rank = $1;
		$songID[$i] = $2;
		#open(TEMP, ">temp1.html");
		#print TEMP $2;
		#close (TEMP);
		
		#print "$1, $2, $3\n";
		print DEBUG "$i - $songID[$i] - $rank\n";
		$i++;
	} # end while
	
	if ($i < $sampleNumber) {
		print ".";
		$offset+= 25;
		$gotonext = 1;
	} # if
	
	if (/Search Results/) {
		$gotonext = 2;
		print "artist has search results\n";
	}
} # do
while $gotonext == 1 || $offset > 400;

if ($gotonext != 2) {

print " -- Found All $i Songs...\n";

mkdir($artistDirectoryName, 0777);
print "$artistDirectoryName\n";


print "enqueueing songs\n";
foreach $temp (@songID) {
	$URL = "http://www.audiogalaxy.com/list/song.php?&g=" . $temp;
	print DEBUG "getting URL\n";
	$_ = get($URL);
	sleep 5;
	s/\\/\-/gi;
	if (/#FFFFFF;\">([^<]+)<\/span>([^<]+)<\/span>/) {
		print DEBUG "found the song in html\n";
		$MP3Title = $1 . $2 . ".mp3";
		$songCheck = $2;
		$songCheck2 = $1 . substr($songCheck, 0, 5);
		$MP3Title =~ tr/[:\*\?\"|]/\-/;
		
		# enqueue song if a similar song hasn't been enqueued already
		$dontEnqueue = 0;
		open(CHECK, "<" . $directory . "Queue.txt");
		while (<CHECK>) {
			if (/$songCheck2/) {
				$dontEnqueue = 1;
				print "Duplicate found for: $MP3Title\n";
			}
		} # while
		close(CHECK);
		
		if ($dontEnqueue != 1) {
			$URL = "http://www.audiogalaxy.com/satellite/queue.php?g=" . $temp. "&SID=" . $SID;
			print DEBUG "getting $URL\n";
			get($URL);
			sleep 5;
			get($URL);
			sleep 5;
			get($URL);
			sleep 5;
		
			print "$MP3Title\n";
			print DEBUG "$MP3Title\n";
			
			# restart the queue if it starts to lag
			if ($temp % 5 == 0) {
				#print "jump starting queue\n";
				$URL = "http://www.audiogalaxy.com/satellite/queue.php?SID=" . $SID;
				$_ = get($URL);
			} # if
			&addToQueue;
			&addToPlaylist;
		} # if
	} # if
} # foreach

} # if gotonext ne 2

&deleteArtist;
print "\n";
sleep 200;

} # do-while loop
while $#artistList > 0;
close(DEBUG);

#####################################
# subroutine to get the name of the artist at the top of the text list of artists
#####################################

sub getArtist {
	$input = $directory . "sampleArtist.txt";
	open(ARTISTLIST, $input);
	@artistList = ();
	$i = 0;
	while (<ARTISTLIST>) {
		s/\n//;
		$artistList[$i] = $_;
		$i++;
	}
	close(ARTISTLIST);
	
	$artist = $artistList[0];
	#print "downloading $sampleNumber songs by $artist\n";
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
# subroutine to append an MP3Title to "Queue.txt"
# given $albumDirectoryName, $MP3Title
#####################################

sub addToQueue {
	$output2 = ">>" . $directory . "Queue.txt";
	open(BATFILE, $output2);
	print BATFILE $MP3Title . "<s>". $artistDirectoryName2 . "<d> d\n";
	print DEBUG "batfile: $artistDirectoryName\\$MP3Title\n";
	close(BATFILE);
}


#####################################
# subroutine to append an MP3Title to playlist
# given $albumDirectoryName, $MP3Title
#####################################

sub addToPlaylist {
	$output3 = ">>" . $artistDirectoryName . $artist . ".m3u";
	open(BATFILE, $output3);
	print BATFILE "$MP3Title\n";
	close(BATFILE);
	
	$output4 = ">>" . $destinationDirectory . "ArtistSampling.m3u";
	open(BATFILE2, $output4);
	print BATFILE2 $artistDirectoryName . "$MP3Title\n";
	close(BATFILE2);
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
		if (/Number of Songs: (\d+) \#/) { $sampleNumber = $1; }
	}
	close(CONFIG);
	
	print "$directory\n";
	print "$destinationDirectory\n";
	print "$downloadDir\n";
	print "$SID\n";
	print "Sample $sampleNumber Songs\n";
}