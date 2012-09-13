#!/usr/bin/env perl -w

while(<>) {

	# split tab delimited data
	@data = split(/\t/);

	$pid      = $ENV{"PID"};
	$db       = $ENV{"DB"};
	$res      = $ENV{"RES"};
	$itemType = "table";

	# $data[1] is NULL indicates item is a view
	if($data[1] eq "NULL") {
		$img = "file://$res/table-view-small-square.tiff";
		$itemType = "view";
	} else {
		$img = "file://$res/table-small-square.tiff";
	}
	
	print <<HTML4;
	<tr>
		<td align=center width='40px'><img src=\"$img\"></td>
		<td><a href=\"sequelpro://$pid\@passToDoc/SelectDatabase/$db/$data[0]/\" title=\"Click to select $itemType “$db.$data[0]”\">$data[0]</a></td>
		<td>$data[1]</td>
		<td align=right>$data[4]</td>
		<td align=right>$data[6]</td>
		<td align=right>$data[11]</td>
		<td align=right>$data[12]</td>
	</tr>
HTML4
}