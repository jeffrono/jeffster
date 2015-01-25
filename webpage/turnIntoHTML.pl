open(OUT, ">leftFrame.htm");
print OUT "<html><title>Master Artist List -- Jeffster 1.1<\/title><\/head><table width=\"100%\" border=\"0\" cellspacing=\"0\" cellpadding=\"1\" align=\"left\">\n";
close(OUT);

open(IN, "<masterArtistList.csv");
$num = 0;
while (<IN>) {
	
	/([^,]+),(\d+),(\d+)/;
	#$num++;
	$artist = $1;
	$ID = $2;
	$rank = $3;
	
	if ($rank > 24 && $num < 200) {
	$num++;
	open(OUT, ">>leftFrame.htm");
	print OUT "<tr";
	
	if ($num % 2 == 0) { print OUT " bgcolor=\"#CCCCCC\""; }
	
	print OUT ">\n";
    	print OUT "<td><b>$artist</b></td>\n";
	print OUT "<td><img src=\"";
	
	#if ($ID < 13) { print OUT "z_0.gif"; }
	#elsif ($ID < 16) { print OUT "1_0.gif"; }
	#elsif ($ID < 19) { print OUT "2_0.gif"; }
	#elsif ($ID < 22) { print OUT "3_0.gif"; }
	#else { 
		print OUT "4_0.gif";
	
	print OUT "\"></td>\n";
	print OUT "<td><a href=\"http:\/\/www.audiogalaxy.com\/list\/artistInfo.php\?&r=$ID\" target=\"mainFrame\"><img src=\"audiogalaxy.gif\" border=\"0\"></a></td>\n";
    	print OUT "<td><a href=\"http:\/\/www.cdnow.com\/cgi\-bin\/mserver\/SID=1188262721\/pagename=\/RP\/CDN\/FIND\/popsearch.html\/clickID=tn_srch_txt\/string=$artist\" target=\"mainFrame\"><img src=\"cdnow.gif\"  border=\"0\"></a></td>\n";
  	print OUT "</tr>\n";
  	} # if
}

print OUT "<\/table><\/body><\/html>";
close(OUT);