#!/usr/local/bin/perl
use DateTime::Calendar::Hebrew;
use DateTime::Event::Sunrise;

my $sunset = DateTime::Event::Sunrise->sunset (
	# Latitude/Longitude for NYC
	longitude =>'-73.59',
	latitude =>'40.38',
);

# Rosh HaShana (Jewish New Year) 2003/5764
$HT = new DateTime::Calendar::Hebrew(
	year   => 5764,
	month  => 7,
	day    => 1,
	hour   => 22,
	minute => 30,
);

# 5764/07/01, because we haven't provided the necessary fields
print $HT->datetime, "\n";

$HT->set(
	sunset => $sunset,
	time_zone => "America/New_York",
);

# 5764/07/02 b/c 10:30pm is always after sunset in NYC.
print $HT->datetime, "\n";
exit;
