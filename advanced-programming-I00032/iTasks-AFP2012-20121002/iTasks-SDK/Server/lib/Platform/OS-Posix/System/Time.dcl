definition module Time
/**
* This module provides an interface to the time definition of the
* C standard library.
*/

from StdString import class toString
import StdOverloaded

/**
* The resolution of the system clock ticks
*/
CLK_PER_SEC	:== 100

/**
* The Tm record structure contains date and time information
* in a broken down format.
*/
:: Tm	= { sec		:: Int	// Seconds (0-61) (generally 0-59. Extra range to accommodate for leap seconds in certain systems.)
		  , min		:: Int	// Minutes (0-59)
		  ,	hour	:: Int	// Hour (0-23)
		  , mday	:: Int	// Day of the month (1-31)
		  , mon		:: Int	// Month (0-11)
		  , year	:: Int	// Years since 1900
		  , wday	:: Int	// Day of the week (0-6, 0 is Sunday)
		  , yday	:: Int	// Day of the year (0-365)
		  , isdst	:: Bool // Daylight saving time flag
		  }

/**
* The time data type represents a number of seconds since the epoch (1-1-1970).
*/
:: Timestamp	= Timestamp !Int
/**
* The clock data type represents a number of CPU clock ticks.
*/
:: Clock		= Clock !Int

instance toString	Tm
instance toString	Clock
instance toString	Timestamp
instance ==			Timestamp
instance <			Timestamp
instance toInt		Timestamp

/**
* Get the number of clock ticks since the process start
*/
clock		:: !*World -> (!Clock, !*World)
/**
* Get the number of seconds since the epoch
*/
time		:: !*World -> (!Timestamp, !*World)
/**
* Get the current time as GMT
*/
gmTime		:: !*World -> (!Tm, !*World)
/**
* Get the current time in the local timezone
*/
localTime	:: !*World -> (!Tm, !*World)
/**
* Convert a Tm record (local time) to a Timestamp value
*/
mkTime		:: !Tm -> Timestamp
/**
* Calculate the difference in seconds between two times
*/
diffTime	:: !Timestamp !Timestamp -> Int
/**
* Format the time structure using the format defined by C's time.h
*/
strfTime	:: !String !Tm -> String
/**
* Convert a timestamp to a Tm record (local time)
*/
toLocalTime :: !Timestamp !*World -> (!Tm,!*World)
/**
* Convert a timestamp to a Tm record (GMT time)
*/
toGmTime    :: !Timestamp -> Tm