use DateTime::Calendar::Hebrew;
use DateTime;
print "1..1\n";

my $birthday = new DateTime(year => 1974, month => 12, day => 19);
my $DT = DateTime::Calendar::Hebrew->from_object(object => $birthday);

if($birthday->utc_rd_as_seconds == $DT->utc_rd_as_seconds) { print "ok\n"; }
else { print "not ok\n"; }

exit;
