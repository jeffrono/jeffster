#####################################
# compare queued files to downloaded files
# each line looks like: blondie - Eat to the Beat Atomic.mp3<s>D:\MP3s\blondie\Eat To The Beat<d> d
#####################################

&configVals;

use File::Copy;
$inputQueue = $directory . "Queue.txt";
@queuedFiles = ();
$queueIndex = 0;
open(QUEUEFILE, "<" . $inputQueue);
while (<QUEUEFILE>) {
	/([^<]+)<s>([^<]+)<d>/;
	$queuedFiles[$queueIndex][0] = $2; # albumpath
	$queuedFiles[$queueIndex][1] = $1; # filename
	$queueIndex++;
}
close(QUEUEFILE);

opendir(DIR, $downloadDir);
@downloaded = readdir(DIR);
closedir(DIR);

$compareIndex = 0;
open(OUTPUT, ">" . $inputQueue);
foreach (@queuedFiles) {
	$marker = 0;
	foreach $dlCompare (@downloaded) {
		# on match
		if ($dlCompare eq $queuedFiles[$compareIndex][1]) {
			$tempPath = $queuedFiles[$compareIndex][0];
			move($downloadDir . $dlCompare, $tempPath);
			print "$dlCompare\n";
			$queuedFiles[$compareIndex][0] = "null";

			# check to see if last song on album, and mark album complete
			$albumIndex = 0;
			$albumMarker = 0;
			foreach(@queuedFiles) {
				if ($compareIndex != $albumIndex && $tempPath eq $queuedFiles[$albumIndex][0]) {
					$albumMarker = 1;
				} # end if
				$albumIndex++;
			} # end foreach queued files, marker is 1 if album is incomplete

			# if complete
			if ($albumMarker == 0) {
				
				# if not sample artist
				if ($tempPath =~ /!/) {
					$tempPath1 = $tempPath;
					$tempPath =~ s/!//;
					rename($tempPath1, $tempPath);
					print "completed $tempPath\n";
				}

			} # end if albummarker = 0

			$marker = 1;
		} #end if "filnames are the same"
	} #foreach dlCompare
	if ($marker == 0) {
		print OUTPUT $queuedFiles[$compareIndex][1] . "<s>" . $queuedFiles[$compareIndex][0] . "<d> d\n";
	}
	$compareIndex++;
} #foreach queuefiles
close(OUTPUT);

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
	print "$directory\n$destinationDirectory\n$downloadDir\n$SID\n";
}