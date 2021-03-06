
/**************************************************************************
VERSION "$Id: sec2timec.c 1 2017-06-10 18:05:20Z coats $"
    EDSS/Models-3 I/O API.

COPYRIGHT
    (C) 1992-2002 MCNC and Carlie J. Coats, Jr., and
    (C) 2003-2010 Baron Advanced Meteorological Systems.
    Distributed under the GNU LESSER GENERAL PUBLIC LICENSE version 2.1
    See file "LGPL.txt" for conditions of use.

PURPOSE
    convert back and forth between Models-3 time conventions and 
    seconds

PRECONDITIONS
    time coded HHMMSS = 100 * ( 100 * hours + minutes ) + seconds

CALLS
    none

REVISION HISTORY
    prototype  3/95 byu CJC

**************************************************************************/

#include  "iodecl3.h"


int sec2timec ( int secs )
    {
    int  time ;
    if ( secs >= 0 )
        {
        time = secs%60  +  100 * ( ( secs/60 ) % 60  +  100 * ( secs/3600 ) ) ;
        }
    else{
        time = -secs ;
        time = -( time%60  +  100*( ( time/60 ) % 60 + 100*( time/3600 ) ) ) ;
        }
    
    return  time ;

    }       /*  end body of sec2timec()  */

