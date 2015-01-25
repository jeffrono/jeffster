#

beginning: {
	
	$offset = 1;
	# enter artist name
	print "\nPlease enter artist name,\n...OR press D to begin downloading albums: ";
	$prompt= <STDIN>;
	chomp($prompt);
	
	# if artist
  if ($prompt ne "D" && $prompt ne "d") {
	$artist = $prompt;
	use LWP::Simple;
	$URL = "http:\/\/www.freedb.org\/freedb_search.php\?words=$artist&allfields=NO&fields=artist&allcats=YES&grouping=none";
	$_ = get($URL);
	
	# make array of artist results
	@artistArray = ();
	$i = 1;
	while(/(\?cat=[^&]+&id=[^\"]+)">([^\/]+) \/ ([^<]+)</gi) {
		$artistArray[$i][0] = $1; # URL
		$artistArray[$i][2] = $2; # Artist
		$artistArray[$i][1] = $3; # Album Name
		$i++;
	} # while
	
	displayTitles: {
	# display offset of titles
	print "\nListing results $offset to ";
	print $offset+15;
	print " (of $i):\n\n";
	for ($j = $offset; $j <= $offset+15; $j++) {
		if ($prompt == $j) { print "**** JUST ADDED *****  "; }
		if ($artistArray[$j][2] ne "") {
			# get number of tracks for album
			$data = get("http://www.freedb.org/freedb_search_fmt.php$artistArray[$j][0]");
			$num = 0;
			while ($data =~ /<\/td><td><b>([^<]+)<\/b>/gi) { $num++; }	
			print $j . "\) $num Tracks - $artistArray[$j][2] - $artistArray[$j][1]\n";
		}
	} # for
	print "\n";
	
	# prompt for action
	print "Type the number of the album you want,\n...OR press ENTER for next page of results,\n...OR press A if done with this artist\n...OR press D to begin download: ";
	$prompt = <STDIN>;
	chomp($prompt);
	} # label displayTitles
	
	# if ENTER
	if ($prompt eq "" && $offset < $i-15) {
		$offset+=15;
		goto displayTitles;
	}
	
	# if numbers
	elsif ($prompt =~ /\d/) {
		open(OUTPUT, ">>albumList.txt");
		print OUTPUT "$artistArray[$prompt][0]<$artistArray[$prompt][1]<$artistArray[$prompt][2]\n";
		close(OUTPUT);
		goto displayTitles;
	}
	
	# give next prompt
	elsif ($prompt eq "A" || $prompt eq "a") {
		goto beginning;
	}
  } # if an artist
  
  else { goto beginDownload; }
  	
} # label beginning


&configVals;
beginDownload: {
   do {
	&getAlbum;
	print "Downloading $artist - $album...\n\n";
	
	$data = get($albumURL);
	$songCountT = 0;
	$songCount = 0;
	@playlist = ();
	# for each song in album
	while ($data =~ /<\/td><td><b>([^<]+)<\/b>/gi) {
		$songName = $1;
		$songCountT++;
		&enqueueSong;
	} # while
	print "($songCount of $songCountT)\n";
	&getTransfers;
	
   if ($songCount > 0) {
	# check if album is complete
	if ($songCount != $songCountT) { $albumDirName = $destinationDirectory . "!" . $artist . " - " . $album . " ($songCount of $songCountT)\\"; }
	else { $albumDirName = $destinationDirectory . "!" . $artist . " - " . $album . "\\"; }
	
	mkdir($albumDirName, 0777);
	print "$albumDirName\n\n";

	$output = ">" . $albumDirName . $album . ".m3u";
	$output2 = ">>" . $directory . "Queue.txt";
	open(BATFILE, $output2);
	open(PLAY, $output);
	foreach $temp (@playlist) {
		print PLAY $temp . "\n";
		print BATFILE $temp . "<s>". $albumDirName . "<d>\n";
	} # foreach
	
	close(PLAY);
	close(BATFILE);
   } # if song count is > 0
	&deleteAlbum;
   } # do loop
   while $#artistList > 0;
} # begin download


#####################
## SUBROUTINES #####
#####################


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

	$URL = "http://www.audiogalaxy.com/list/song.php?&g=" . $songID;
	$_ = get($URL);
	sleep 5;
	s/\\/\-/gi;
	
	if (/#FFFFFF;\">([^<]+)<\/span>([^<]+)<\/span>/ && $errorMark != 1) {
		$songCheck = $2;
		$MP3Title = $1 . $2 . ".mp3";
		$MP3Title =~ tr/[:\*\?\"|]/\-/;
		
		#enqueue song
		$URL = "http://www.audiogalaxy.com/satellite/queue.php?g=" . $songID. "&SID=" . $SID;
		$_ = get($URL);
		#sleep 2;
		
		# add to queue and playlist if it's downloading
		$URL = "http://www.audiogalaxy.com/satellite/queue.php?SID=" . $SID;
		$_ = get($URL);
		#sleep 2;
		if (/$songCheck/gi) {
			$isInEnqueue = 1;
			print "$MP3Title: $errorMark\n";
			$playlist[$songCount] = $MP3Title;
			$songCount++;
		} # if songcheck
	} # if FFFFF
	
	# if not in enqueue, wait
	if($isInEnqueue == 0 && $errorMark != 1) { print "."; }
	
	} # do loop
	until ($isInEnqueue == 1 || $errorMark == 1);
}


#####################################
# subroutine to get the name of the artist at the top of the text list of artists
#####################################

sub getAlbum {
	$input = $directory . "albumList.txt";
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
	
	/([^<]+)<([^<]+)<(.+)/;
	$albumURL = "http://www.freedb.org/freedb_search_fmt.php" . $1;
	$album = $2;
	$artist = $3
}

#####################################
# delete the top artist from the list of artists
#####################################

sub deleteAlbum {
	$output = ">" . $input;
	open(ARTISTLIST, $output);
	for ($i = 1; $i <= $#artistList; $i++) {
		print ARTISTLIST $artistList[$i] . "\n";
	}
	close(ARTISTLIST);
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
	print "$SID\n\n";
}


#####################################
# get numbers of transferring mp3s
#####################################
sub getTransfers {
	$URL = "http://www.audiogalaxy.com/satellite/queue.php?SID=" . $SID;
	$_ = get($URL);
	/(\d+)&nbsp;transferring/g;
	print "Transferring: $1";
	/(\d+)&nbsp;processing/g;
	print " -- Processing: $1";
	/(\d+)&nbsp;busy/g;
	print " -- Busy: $1";
	/(\d+)&nbsp;offline/g;
	print " -- Offline: $1\n";
} # get transfers
