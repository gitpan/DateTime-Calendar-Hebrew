use DateTime::Calendar::Hebrew;
print "1..1\n";

# the date the Israelites left Egypt
my $DT = new DateTime::Calendar::Hebrew(
	year => 2449,
	month => 1,
	day => 15,
);

my $clone = $DT->clone;
if($DT->utc_rd_as_seconds == $clone->utc_rd_as_seconds) { print "ok\n"; }
else { print "not ok\n"; }

exit;
