package DateTime::Calendar::Hebrew;

use vars qw($VERSION);
$VERSION = '0.01';

use strict;

use DateTime;
use Params::Validate qw/validate SCALAR OBJECT CODEREF/;

use constant HEBREW_EPOCH => -1373429;

sub new {
    my $class = shift;
    my %p = validate( @_,
                      { year       => { type => SCALAR },
                        month      => { type => SCALAR, default => 1,
									    callbacks => {
											'is between 1 and 13' =>
											sub { $_[0] >= 1 && $_[0] <= 13 }
									    }
									  },
                        day        => { type => SCALAR, default => 1,
									    callbacks => {
											'is between 1 and 30' =>
											sub { $_[0] >= 1 && $_[0] <= 30 }
									    }
									  },
						hour       => { type => SCALAR, default => 0,
									    callbacks => {
											'is between 0 and 23' =>
											sub { $_[0] >= 0 && $_[0] <= 23 }
									    }
									  },
						minute     => { type => SCALAR, default => 0,
									    callbacks => {
											'is between 0 and 59' =>
											sub { $_[0] >= 0 && $_[0] <= 59 }
									    }
									  },
						second     => { type => SCALAR, default => 0,
									    callbacks => {
											'is between 0 and 59' =>
											sub { $_[0] >= 0 && $_[0] <= 59 }
									    }
									  },
						nanosecond => { type => SCALAR, default => 0 },
						sunset     => { type => CODEREF, optional => 1 },
						time_zone  => { type => SCALAR | OBJECT, default => 'floating' },
                      } );

    my $self = bless \%p, $class;

	$self->{rd_days} = &_to_rd(@p{ qw(year month day) });
	$self->{rd_secs} = $p{hour} * 60 * 60 + $p{minute} * 60 + $p{second};
	$self->{rd_nanosecs} = $p{nanosecond};

	if(my $coderef = $self->{sunset}) {
		my $time_in_seconds = $self->{rd_secs};
		my $DT = DateTime->from_object(object => $self);
		my ($y, $m, $d) = split(/-/, $DT->ymd);
		my $sunset = &$coderef($y, $m, $d);
		if($time_in_seconds > $sunset) { 
			$self->{rd_days}++;
			@{$self}{ qw( year month day ) } = &_from_rd($self->{rd_days});
		}
	}

    return $self;
}

sub from_object {
	my $class = shift;
	my %p = validate ( @_, {
		object => {
			type => OBJECT,
			can => 'utc_rd_values',
		},
	});

	my $object = delete $p{object};

	my ( $rd_days, $rd_secs, $rd_nanosecs ) = $object->utc_rd_values;

	my %args;
	@args{ qw( year month day ) } = &_from_rd($rd_days);

	my($hour, $minute, $second);
	$second = $rd_secs % 60;
	$minute = $rd_secs / 60;
	$hour = int($minute / 60);
	$minute = $minute % 60;
	@args{ qw( hour minute second ) } = ($hour, $minute, $second);

	$args{nanosecond} = $rd_nanosecs || 0;

	my $new_object = $class->new(%args);

	return $new_object;
}

sub set {
    my $self = shift;
    my %p = validate( @_,
                      { year     => { type => SCALAR, optional => 1 },
                        month    => { type => SCALAR, optional => 1,
									  callbacks => {
										'is between 1 and 13' =>
										sub { $_[0] >= 1 && $_[0] <= 13 }
									  }
									},
                        day      => { type => SCALAR, optional => 1,
									  callbacks => {
										'is between 1 and 30' =>
										sub { $_[0] >= 1 && $_[0] <= 30 }
									  }
									},
						hour     => { type => SCALAR, optional => 1,
									  callbacks => {
										'is between 0 and 23' =>
										sub { $_[0] >= 0 && $_[0] <= 23 }
									  }
									},
						minute   => { type => SCALAR, optional => 1,
									  callbacks => {
										'is between 0 and 59' =>
										sub { $_[0] >= 0 && $_[0] <= 59 }
									  }
									},
						second   => { type => SCALAR, optional => 1,
									  callbacks => {
										'is between 0 and 59' =>
										sub { $_[0] >= 0 && $_[0] <= 59 }
									  }
									},
						nanosecond => { type => SCALAR, optional => 1 },
						sunset => { type => CODEREF, optional => 1 },
                      } );

    $self->{$_} = $p{$_} for keys %p;

	$self->{rd_days} = &_to_rd($self->{year}, $self->{month}, $self->{day});
    $self->{rd_secs} = $self->{hour} * 60 * 60 + $self->{minute} * 60 + $self->{second};
	$self->{rd_nanosecs} = $self->{nanosecond};

	if(my $coderef = $self->{sunset}) {
		my $time_in_seconds = $self->{rd_secs};
		my $DT = DateTime->from_object(object => $self);
		my ($y, $m, $d) = split(/-/, $DT->ymd);
		my $sunset = &$coderef($y, $m, $d);
		if($time_in_seconds > $sunset) { 
			$self->{rd_days}++;
			@{$self}{ qw( year month day ) } = &_from_rd($self->{rd_days});
		}
	}

    return $self;
}

sub utc_rd_values { return @{$_[0]}{ qw/rd_days rd_secs rd_nanosecs/ }; }

sub utc_rd_as_seconds {
    my $self = shift;
    my ($rd_days, $rd_secs, $rd_nanosecs) = $self->utc_rd_values;

    if (defined $rd_days) {
        return $rd_days*24*60*60 + $rd_secs;
    } else {
        return undef;
    }
}

sub clone {
    my $self = shift;
    return bless {%$self}, ref $self;
}

sub now {
    my $class = shift;
    $class = ref($class) || $class;

    my $dt = DateTime->now;
    my $ht = $class->from_object(object => $dt);
    return($ht);
}

sub today {
    my $class = shift;
    $class = ref($class) || $class;

    my $dt = DateTime->today;
    my $ht = $class->from_object(object => $dt);
    return($ht);
}

sub _from_rd {
    my $rd = shift;

    my ($year, $month, $day);
    $year = int(($rd - HEBREW_EPOCH) / 366);
    while ($rd >= &_to_rd($year + 1, 7, 1)) { $year++; }
    if ($rd < &_to_rd($year, 1, 1)) { $month = 7; }
    else { $month = 1; }
    while ($rd > &_to_rd($year, $month, (&_LastDayOfMonth($year, $month)))) { $month++; }
    $day = $rd - &_to_rd($year, $month, 1) + 1;

	return $year, $month, $day;
}

sub _to_rd {
    my ($year, $month, $day) = @_;
	if(scalar @_) { 
		($year, $month, $day) = @_;
	}

    my($m, $DayInYear);

    $DayInYear = $day;
    if ($month < 7) {
		$m = 7;
		while ($m <= (&_LastMonthOfYear($year))) {
			$DayInYear += &_LastDayOfMonth($year, $m++);
		}
		$m = 1;
		while ($m < $month) {
			$DayInYear += &_LastDayOfMonth($year, $m);
			$m++;
		}
    }
    else {
		$m = 7;
		while ($m < $month) {
			$DayInYear += &_LastDayOfMonth($year, $m);
			$m++;
		}
    }

    return($DayInYear + (&_CalendarElapsedDays($year) + HEBREW_EPOCH));
}

sub _leap_year {
    my $year = shift;

	if ((((7 * $year) + 1) % 19) < 7) { return 1; }
    else { return 0; }
}

sub _LastMonthOfYear {
    my $year = shift;

    if (&_leap_year($year)) { return 13; }
    else { return 12; }
}

sub _CalendarElapsedDays {
	my $year = shift;

    my($MonthsElapsed, $PartsElapsed, $HoursElapsed, $ConjunctionDay, $ConjunctionParts);
    my($AlternativeDay);

    $MonthsElapsed = (235 * int(($year - 1) / 19)) + (12 * (($year - 1) % 19)) + int((7 * (($year - 1) % 19) + 1) / 19);
    $PartsElapsed = 204 + 793 * ($MonthsElapsed % 1080);
    $HoursElapsed = 5 + 12 * $MonthsElapsed + 793 * int($MonthsElapsed / 1080) + int($PartsElapsed / 1080);
    $ConjunctionDay = 1 + 29 * $MonthsElapsed + int($HoursElapsed / 24);
    $ConjunctionParts = 1080 * ($HoursElapsed % 24) + $PartsElapsed % 1080;

    $AlternativeDay = 0;
    if (($ConjunctionParts >= 19440) ||
	((($ConjunctionDay % 7) == 2)
	 && ($ConjunctionParts >= 9924)
	 && (!&_leap_year($year))) ||
	((($ConjunctionDay % 7) == 1)
	 && ($ConjunctionParts >= 16789)
	 && (&_leap_year($year - 1))))
    { $AlternativeDay = $ConjunctionDay + 1; }
    else    { $AlternativeDay = $ConjunctionDay; }

    if ((($AlternativeDay % 7) == 0) ||
	(($AlternativeDay % 7) == 3) ||
	(($AlternativeDay % 7) == 5))
    { return (1 + $AlternativeDay); }
    else    { return $AlternativeDay; }
}

sub _DaysInYear {
	my $year = shift;
    return ((&_CalendarElapsedDays($year + 1)) - (&_CalendarElapsedDays($year)));
}

sub _LongCheshvan {
	my $year = shift;
    if ((&_DaysInYear($year) % 10) == 5) { return 1; }
    else { return 0; }
}       

sub _ShortKislev {
	my $year = shift;
    if ((&_DaysInYear($year) % 10) == 3) { return 1; }
    else { return 0; }
}

sub _LastDayOfMonth {
    my ($year, $month) = @_;

    if (($month == 2) ||
	($month == 4) ||
	($month == 6) ||
	(($month == 8) && (! &_LongCheshvan($year))) ||
	(($month == 9) && &_ShortKislev($year)) ||
	($month == 10) ||
	(($month == 12) && (!&_leap_year($year))) ||
	($month == 13)) { return 29; }
    else { return 30; }
}

sub month_name {
	my $self = shift;
	my $month = $self->month;
	if(@_) { $month = shift; }

    return (qw/Nissan Iyar Sivan Tamuz Av Elul Tishrei Cheshvan Kislev Tevet Shevat AdarI AdarII/)[$month-1];
}

sub day_name {
	my $self = shift;
	my $day = $self->day_of_week;
	if(@_) { $day = shift; }

    return (qw/Sunday Monday Tuesday Wednesday Thursday Friday Shabbat/)[$day - 1];
}

sub year    { $_[0]->{year} }

sub month   { $_[0]->{month} }
*mon = \&month;

sub month_0   { $_[0]->{month} - 1 }
*mon_0 = \&month_0;

sub day_of_month { $_[0]->{day} }
*day  = \&day_of_month;
*mday = \&day_of_month;

sub day_of_month_0 { $_[0]->{day} - 1 }
*day_0  = \&day_of_month_0;
*mday_0 = \&day_of_month_0;

sub day_of_week {
	my $rd_days = $_[0]->{rd_days};
	return $rd_days % 7 + 1;
}
*wday = \&day_of_week;
*dow  = \&day_of_week;

sub day_of_week_0 {
	my $rd_days = $_[0]->{rd_days};
	return $rd_days % 7;
}
*wday_0 = \&day_of_week_0;
*dow_0  = \&day_of_week_0;

sub week_number {
    my $self = shift;

	my $day_of_year = $self->day_of_year;
	my $start_of_year = &_to_rd($self->{year}, 1, 1);
	my $first_week_started_on = $start_of_year % 7 + 1;

	return (($day_of_year + (7 - $first_week_started_on)) / 7) + 1;
}

sub day_of_year {
	my $self = shift;
    my ($year, $month, $day) = @{$self}{qw/year month day/};

	my $m = 1;
	while ($m < $month) {
		$day += $self->_LastDayOfMonth($year, $m);
		$m++;
	}
	return $day;
}
*doy = \&day_of_year;

sub day_of_year_0 { $_[0]->day_of_year - 1; }
*doy_0 = \&day_of_year_0;

sub ymd {
    my ($self, $sep) = @_;
    $sep = '-' unless defined $sep;

    return sprintf( "%04d%s%02d%s%02d",
                    $self->{year}, $sep,
                    $self->{month}, $sep,
                    $self->{day} );
}
*date = \&ymd;

sub mdy {
    my ($self, $sep) = @_;
    $sep = '-' unless defined $sep;

    return sprintf( "%02d%s%02d%s%04d",
                    $self->{month}, $sep,
                    $self->{day}, $sep,
                    $self->{year} );
}
sub dmy {
    my ($self, $sep) = @_;
    $sep = '-' unless defined $sep;

    return sprintf( "%02d%s%02d%s%04d",
                    $self->{day}, $sep,
                    $self->{month}, $sep,
                    $self->{year} );
}

sub hour    { $_[0]->{hour} }
*hr = \&hour;

sub minute    { $_[0]->{minute} }
*min = \&minute;

sub second    { $_[0]->{second} }
*sec = \&second;

my %formats = (
      'A' => sub { $_[0]->day_name },
      'a' => sub { my $a = $_[0]->day_of_week_0; (qw/Sun Mon Tue Wed Thu Fri Shabbat/)[$a] },
      'B' => sub { $_[0]->month_name },
      'd' => sub { sprintf( '%02d', $_[0]->day) },
      'D' => sub { $_[0]->strftime( '%m/%d/%Y') },
      'e' => sub { sprintf( '%2d', $_[0]->day) },
      'F' => sub { $_[0]->ymd('-') },
      'j' => sub { sprintf('%03d', $_[0]->day_of_year) },
      'H' => sub { sprintf('%02d', $_[0]->hour) },
	  'I' => sub { ($_[0]->hour == 12) ? '12' : sprintf('%02d', ($_[0]->hour % 12)) },
      'k' => sub { sprintf('%2d', $_[0]->hour) },
	  'l' => sub { ($_[0]->hour == 12) ? '12' : sprintf('%2d', ($_[0]->hour % 12)) },
      'M' => sub { sprintf('%02d', $_[0]->minute) },
      'm' => sub { sprintf('%02d', $_[0]->month) },
      'n' => sub { "\n" },
	  'P' => sub { ($_[0]->hour >= 12) ? "PM" : "AM" },
	  'p' => sub { ($_[0]->hour >= 12) ? "pm" : "am" },
      'r' => sub { $_[0]->strftime( '%I:%M:%S %p') },
      'R' => sub { $_[0]->strftime( '%H:%M') },
      'S' => sub { sprintf('%02d', $_[0]->second) },
      'T' => sub { $_[0]->strftime( '%H:%M:%S') },
      't' => sub { "\t" },
	  'u' => sub { my $u = $_[0]->day_of_week_0; $u == 0 ? 7 : $u },
	  'U' => sub { my $w = $_[0]->week_number; defined $w ? sprintf('%02d', $w) : '  ' },
	  'w' => sub { $_[0]->day_of_week_0 },
	  'W' => sub { sprintf('%02d', $_[0]->week_number) },
      'y' => sub { sprintf('%02d', substr($_[0]->year, -2)) },
      'Y' => sub { return $_[0]->year },
      '%' => sub { '%' },
    );
$formats{W} = $formats{V} = $formats{U};

sub strftime {
    my ($self, @r) = @_;

    foreach (@r) {
        s/%([%*A-Za-z])/ $formats{$1} ? $formats{$1}->($self) : $1 /ge;
        return $_ unless wantarray;
    }
    return @r;
}



1;
__END__

=head1 NAME

DateTime::Calendar::Hebrew - Dates in the Hebrew calendar

=head1 SYNOPSIS

  use DateTime::Calendar::Hebrew;

  $dt = DateTime::Calendar::Hebrew->new( year  => 5782,
                                         month => 10,
                                         day   => 4 );

=head1 DESCRIPTION

DateTime::Calendar::Hebrew is the implementation of the Hebrew calendar.
See README.hebrew for more details on the Hebrew calendar.

=head1 METHODS

=over 4

=item * new(...)

	$dt = new Date::Calendar::Hebrew(
		year => 5782,
		month => 10,
		day => 5,
	);

This class method accepts parameters for each date and time component:
"year", "month", "day", "hour", "minute", "second", "nanosecond" and
"timezone". "year" is required, all the rest are optional. time fields
default to '0', month/day fields to '1', timezone to 'floating'. All
fields except year and timezone  are tested for validity:

	month : 1 to 13
	day   : 1 to 30
	hour  : 0 to 23
	minute/second : 0 to 59

The days on the Hebrew calendar begin at sunset. 
If you want to know the Hebrew date, accurate with regard to local sunset, you can add a 'sunset' parameter.
The sunset parameter must be a function-reference that accepts the parameters (year, month, day) and returns the time for sunset,
local to your DateTime, in seconds-since-midnight. See README.sunset for more info.

=item * from_object(object => $object)

This class method can be used to construct a new object from
any object that implements the C<utc_rd_values()> method.  All
C<DateTime::Calendar> modules must implement this method in order to
provide cross-calendar compatibility.

=item * set(...)

	$dt->set(
		year  => 5782,
		month => 1,
		day   => 1,
	);

This method allows you to modify the values of the object. valid
fields are "year", "month", "day", "hour", "minute", "second",
"nanosecond" and "sunset". Returns the object being modified.
Values are checked for validity just as they are in new().

=item * utc_rd_values

Returns the current UTC Rata Die days and seconds as a three element
list.  This exists primarily to allow other calendar modules to create
objects based on the values provided by this object.

=item * utc_rd_as_seconds

Returns the current UTC Rata Die days and seconds purely as seconds.
This is useful when you need a single number to represent a date.

=item * clone

Returns a working copy of the object. 

=item * now

This class method returns an object created from DateTime->now.

=item * today

This class method returns an object created from DateTime->today.

=item * year

Returns the year.

=item * month

Returns the month of the year, from 1..13.

=item * day_of_month, day, mday

Returns the day of the month, from 1..30.

=item * day_of_month_0, day_0, mday_0

Returns the day of the month, from 0..29.

=item * month_name($month);

Returns the name of the given month.  Called on an object ($dt->month_name), it returns the month name for the current month.

The Hebrew months are Nissan, Iyar, Sivan, Tammuz, (Menachem)Av, Elul, Tishrei, (Mar)Cheshvan, Kislev, Teves, Shevat & Adar. Leap years have "Adar II" or Second-Adar. If you feel that the order of the months is wrong, see README.hebrew.

=item * day_of_week, wday, dow

Returns the day of the week as a number, from 1..7, with 1 being
Sunday and 7 being Saturday.

=item * day_of_week_0, wday_0, dow_0

Returns the day of the week as a number, from 0..6, with 0 being
Sunday and 6 being Saturday.

=item * day_name

Returns the name of the current day of the week.

=item * day_of_year, doy

Returns the day of the year.

=item * day_of_year_0, doy_0

Returns the day of the year, starting with 0.

=item * ymd($optional_separator);

=item * mdy($optional_separator);

=item * dmy($optional_separator);

Each method returns the year, month, and day, in the order indicated
by the method name.  Years are zero-padded to four digits.  Months and
days are 0-padded to two digits.

By default, the values are separated by a dash (-), but this can be
overridden by passing a value to the method.

=item * hour   

=item * minute   

=item * second   

Each method returns the parameter named in the method.

=item * strftime($format, ...)

This method implements functionality similar to the C<strftime()>
method in C.  However, if given multiple format strings, then it will
return multiple elements, one for each format string.

See L<DateTime> for a list of all possible format specifiers.
I implemented as many of them as I could.

=head1 INTERNAL FUNCTIONS

=item * _from_rd($RD);

Calculates the Hebrew year, month and day from the RD.

=item * _to_rd($year, $month, $day);

Calulates the RD from the  Hebrew year, month and day.

=item * _leap_year($year);

Returns true if the given year is a Hebrew leap-year.

=item * _LastMonthOfYear($year);

Returns the number of the last month in the given Hebrew year. Leap-years have 13 months, Regular-years have 12.

=item * _CalendarElapsedDays($year);

Returns the number of days that have passed from the Epoch of the Hebrew Calendar to the first day ofthe given year.

=item * _DaysInYear($year);

Returns the number of days in the given year.

=item * _LongCheshvan($year);

Returns true if the given year has an extended month of Cheshvan. Cheshvan can have 29 or 30 days. Normally it has 29.

=item * _ShortKislev($year);

Returns true if the given year has a shortened month of Kislev. Kislev can have 29 or 30 days. Normally it has 30.

=item * _LastDayOfMonth($year, $month);

Returns the length of the month in question, for the year in question.

=back

=head1 BUGS

=over 4

=item * I must not have tested it enough, I'm not aware of any.

=back

=head1 SUPPORT

Support for this module is provided via the datetime@perl.org email
list. See http://lists.perl.org/ for more details.

=head1 AUTHOR

Steven J. Weinberger <perl@psycomp.com>

=head1 COPYRIGHT

Copyright (c) 2003 Steven J. Weinberger.  All rights reserved.  This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<DateTime>

datetime@perl.org mailing list

=cut
