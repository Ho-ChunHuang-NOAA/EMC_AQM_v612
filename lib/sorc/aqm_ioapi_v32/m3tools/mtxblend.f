
        PROGRAM MTXBLEND

C***********************************************************************
C Version "$Id: mtxblend.f 1 2017-06-10 18:05:20Z coats $"
C EDSS/Models-3 M3TOOLS.
C Copyright (C) 1992-2002 MCNC, (C) 1995-2002,2005-2013 Carlie J. Coats, Jr.,
C and (C) 2002-2010 Baron Advanced Meteorological Systems. LLC.
C Distributed under the GNU GENERAL PUBLIC LICENSE version 2
C See file "GPL.txt" for conditions of use.
C.........................................................................
C  program body starts at line   100
C
C  DESCRIPTION:
C       Reads sparse (grid-to-grid transform) matrix S and two
C       input data files:  the "base" file and the "blend" file.
C       Computes "blend factors" F according to the formula
C       F_{base-cell} = SUM_{input cells} S_{input cell}{base-cell}
C       For each time step in the specified time step sequence,
C       reads all variables from the specified input files, optionally
C       under the control of the specified synchronization file,
C       uses the sparse matrix to transform it to the specified
C       output grid, blends it with the base file according to the
C       fromula  OUT = F * BASE + S * BLEND   and writes it to the
C       specified output file.
C
C  PRECONDITIONS REQUIRED:
C       setenv <logical name> <physical (path) name> for the input,
C       output, and GRIDDESC files.
C       Input file and output grid use the same coordinate system.
C       Specified time step sequence is valid for both the input and
C       synch files.
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C       I/O API
C
C  REVISION  HISTORY:
C       Adapted  9/2000 by Carlie J. Coats, Jr., NCSC, from "m3cple.f"
C       Version 11/2001 by CJC for I/O API Version 2.1
C       Version  6/2005 by CJC:  improved default for NRECS
C       Version  11/2005 by CJC:  eliminate unused vbles
C       Version  02/2010 by CJC for I/O API v3.1:  Fortran-90 only;
C       USE M3UTILIO, and related changes.
C       Version 01/2013 by CJC:  use new LASTTIME() to find EDATE:ETIME
C***********************************************************************

      USE M3UTILIO
      IMPLICIT NONE

C...........   PARAMETERS and their descriptions:

       CHARACTER*16, PARAMETER :: PNAME = 'MTXBLEND'

C...........   LOCAL VARIABLES and their descriptions:

        CHARACTER*16    MNAME   !  input matrix file logical name
        CHARACTER*16    FNAME   !  input data   file logical name
        CHARACTER*16    GNAME   !  base  data   file logical name
        CHARACTER*16    SNAME   !  input synch  file logical name
        CHARACTER*16    SVBLE   !  input   synch variable   name
        CHARACTER*16    ONAME   !  output data file logical name
        CHARACTER*16    IGRID   !  output grid name
        CHARACTER*16    OGRID   !  output grid name

        LOGICAL         SFLAG   !  true iff controlled by synch file

        CHARACTER*256   MESG

        INTEGER         LDEV        !  log-device
        INTEGER         STATUS      !  allocation-status

        INTEGER         V, N, L, C, R     !  loop counters

        INTEGER         NCOLS1      ! number of input-grid columns
        INTEGER         NROWS1      ! number of input-grid rows
        INTEGER         NSIZE1      ! number of input-grid cells

        INTEGER         NCOLSM      ! number of matrix coeffs
        INTEGER         NROWSM      ! number of matrix rows

        INTEGER         NCOLS2      ! number of grid columns
        INTEGER         NROWS2      ! number of grid rows
        INTEGER         JDATE, JTIME, TSTEP
        INTEGER         EDATE, ETIME, TSECS, NRECS

        INTEGER::      TYPES( 3 ) =
     &       (/ GRDDED3, BNDARY3, CUSTOM3 /)

        CHARACTER*72:: TMENU( 3 ) =
     &       (/ 'Output file type GRIDDED  ',
     &          'Output file type BOUNDARY ',
     &          'Output file type CUSTOM   ' /)

        REAL,    ALLOCATABLE::   IBUF( :, :, : )
        REAL,    ALLOCATABLE::   OBUF( :, :, : )
        REAL,    ALLOCATABLE::   MASK( : )
        REAL,    ALLOCATABLE::   CBUF( : )


C***********************************************************************
C   begin body of program MTXBLEND

        LDEV = INIT3()

        WRITE( *, '( 5X, A )' )
     & ' ',
     & 'Program MTXBLEND to read a sparse (grid-to-grid transform)',
     & 'matrix, and then all variables in each time step in the',
     & 'specified time step sequence from the specified input',
     & 'file, optionally under the control of the specified',
     & 'synchronization file, copy or interpolate them to the ',
     & 'output grid, use them to replace where appropriate the values',
     & 'from a base-case file, and write them to the specified output',
     & 'file.',
     & ' ',
     & 'THE PROGRAM WILL PROMPT YOU for the logical names of the',
     & 'input matrix file, the input data file, the input synch file',
     & 'the GRIDDESC name of the output grid, the output file, the',
     & 'time step sequence.',
     & 'Default responses are indicated in square brackets',
     & '[LIKE THIS], and may be accepted by hitting the RETURN key.',
     & ' ',
     & 'PRECONDITIONS REQUIRED:',
     & ' ',
     & '    setenv <input matrix file>    <path-name>',
     & '    setenv <input data   file>    <path-name>',
     & '    setenv <base  data   file>    <path-name>',
     & '    setenv <input synch  file>    <path-name, or "NONE">',
     & '    time step sequence is valid for both input files',
     & '    File type must be GRIDDED, BOUNDARY, or CUSTOM.',
     &' ',
     &'See URL',
     &'https://www.cmascenter.org/ioapi/documentation/3.1/html#tools',
     & ' ',
     &'Program copyright (C) 1992-2002 MCNC, (C) 1995-2013',
     &'Carlie J. Coats, Jr., and (C) 2002-2010 Baron Advanced',
     &'Meteorological Systems, LLC.  Released under Version 2',
     &'of the GNU General Public License. See enclosed GPL.txt, or',
     &'URL http://www.gnu.org/copyleft/gpl.html',
     &' ',
     &'Comments and questions are welcome and can be sent to',
     &' ',
     &'    Carlie J. Coats, Jr.    carlie@jyarborough.com',
     &'or',
     &'    UNC Institute for the Environment',
     &'    137 E. Franklin St. Suite 602 Room 613-C',
     &'    Campus Box 1105',
     &'    Chapel Hill, NC 27599-1105',
     &' ',
     &'Program version: ',
     &'$Id:: mtxblend.f 1 2017-06-10 18:05:20Z coats                 $',
     &' '

        IF ( .NOT. GETYN( 'Continue with program?', .TRUE. ) ) THEN
            CALL M3EXIT( PNAME, 0, 0,
     &                   'Program terminated at user request', 2 )
        END IF


C...............  Open and get description for optional synch file

        MESG = 'Enter name for input synch file, or "NONE"'
        SNAME = PROMPTMFILE( MESG, FSREAD3, 'SYNCH_FILE', PNAME )

        CALL LUSTR( SNAME )
        SFLAG = ( SNAME .NE. 'NONE ' )

        IF ( SFLAG ) THEN

            IF ( .NOT. DESC3( SNAME ) ) THEN
                MESG = 'Could not get file description for ' // SNAME
                CALL M3EXIT( PNAME, 0, 0, MESG, 2 )
            END IF

            NCOLS2 = NCOLS3D
            NROWS2 = NROWS3D
            SVBLE  = VNAME3D( 1 )

        END IF          !  if synch-flag option taken


C...............  Open and get description for input matrix transform file

        MESG  = 'Enter name for input matrix transform file'
        MNAME = PROMPTMFILE( MESG, FSREAD3, 'MATRIX_FILE', PNAME )

        IF ( .NOT. DESC3( MNAME ) ) THEN
            MESG = 'Could not get file description for ' // MNAME
            CALL M3EXIT( PNAME, 0, 0, MESG, 2 )
        END IF

        NCOLSM = NCOLS3D
        NROWSM = NROWS3D

        IGRID = ' '
        OGRID = ' '
        DO L = 1, MXDESC3
            IF ( FDESC3D( L )( 1:8 ) .EQ. '#INGRID' ) THEN
               N     = LBLANK( FDESC3D( L )( 9  :80 ) )
               IGRID = TRIM  ( FDESC3D( L )( 9+N:80 ) )
            ELSE IF ( FDESC3D( L )( 1:8 ) .EQ. '#OUTGRID' ) THEN
               N     = LBLANK( FDESC3D( L )( 9  :80 ) )
               OGRID = TRIM  ( FDESC3D( L )( 9+N:80 ) )
            END IF
        END DO


C...............  Open and get description for input data file 1

        MESG  = 'Enter name for input-merge data file'
        FNAME = PROMPTMFILE( MESG, FSREAD3, 'IN_DATA', PNAME )

        IF ( .NOT. DESC3( FNAME ) ) THEN
            MESG = 'Could not get file description for ' // FNAME
            CALL M3EXIT( PNAME, 0, 0, MESG, 2 )
        END IF

        NCOLS1 = NCOLS3D
        NROWS1 = NROWS3D
        IF ( FTYPE3D .EQ. GRDDED3 ) THEN
            NSIZE1 = NCOLS1 * NROWS1
        ELSE IF ( FTYPE3D .EQ. BNDARY3 ) THEN
            NSIZE1 = 2*ABS( NTHIK3D )*( NCOLS3D + NROWS3D + 2*NTHIK3D )
        ELSE IF ( FTYPE3D .EQ. CUSTOM3 ) THEN
            NSIZE1 = NCOLS3D
        END IF

        IGRID   = GDNAM3D


C...............  Open and get description for input data file 2

        MESG  = 'Enter name for base data file'
        GNAME = PROMPTMFILE( MESG, FSREAD3, 'BASE_DATA', PNAME )

        IF ( .NOT. DESC3( GNAME ) ) THEN
            MESG = 'Could not get file description for ' // GNAME
            CALL M3EXIT( PNAME, 0, 0, MESG, 2 )
        END IF

        OGRID   = GDNAM3D


C...............  Get output grid description, time step sequence

        IF ( IGRID .EQ. ' ' ) THEN
            CALL GETSTR('Enter input grid name','UK10_84X130',IGRID )
        END IF

        MESG = 'Interpolating from grid "' // TRIM( IGRID ) //
     &         '" to grid "'               // TRIM( OGRID ) // '"'
        CALL M3MSG2( MESG )

        JDATE = GETNUM( SDATE3D, 9999999, SDATE3D,
     &                  'Enter STARTING DATE for time step sequence' )

        JTIME = GETNUM(       0, 9999999, STIME3D,
     &                  'Enter STARTING TIME for time step sequence' )

        TSTEP = GETNUM( TSTEP3D, 9999999, TSTEP3D,
     &                  'Enter   TIME STEP   for time step sequence' )

        CALL LASTTIME( SDATE3D,STIME3D,TSTEP3D, MXREC3D, EDATE,ETIME )
        N  =  CURREC( EDATE, ETIME, JDATE, JTIME, TSTEP, C, R )

        NRECS = GETNUM( 1, 9999999, N,
     &                  'Enter     NRECS     for time step sequence' )

        SDATE3D = JDATE
        STIME3D = JTIME
        TSTEP3D = TSTEP


C...............  Create output file, borrowing most of file
C...............  description from FNAME, grid-description part
C...............  from GRIDDESC file:

        IF ( FTYPE3D .EQ. GRDDED3 ) THEN
            IF ( NROWSM .NE. NCOLS3D*NROWS3D ) THEN
                MESG = 'Matrix NROWS does not match output NROWS*NCOLS'
                CALL M3MSG2( MESG )
                MESG = 'Inconsistent dimensions for sparse matrix'
                CALL M3EXIT( PNAME, 0, 0, MESG, 2 )
            END IF
        ELSE IF ( FTYPE3D .EQ. BNDARY3 ) THEN
            N = 2*ABS( NTHIK3D )*( NCOLS3D + NROWS3D + 2*NTHIK3D )
            IF ( NROWSM .NE. N ) THEN
                MESG = 'Matrix NROWS does not match output PERIMETER'
                CALL M3MSG2( MESG )
                MESG = 'Inconsistent dimensions for sparse matrix'
                CALL M3EXIT( PNAME, 0, 0, MESG, 2 )
            END IF
        ELSE IF ( FTYPE3D .EQ. CUSTOM3 ) THEN
            IF ( NROWSM .NE. NCOLS3D ) THEN
                MESG = 'Matrix NROWS does not match output NCOLS'
                CALL M3MSG2( MESG )
                MESG = 'Inconsistent dimensions for input vector'
                CALL M3EXIT( PNAME, 0, 0, MESG, 2 )
            END IF
        END IF

        !!  Use the first empty FDESC3D line to describe the
        !!  interpolation source and target grids:

        DO L = 1, MXDESC3
            IF ( ( FDESC3D( L )        .EQ. ' ' ) .OR.
     &           ( FDESC3D( L )( 1:1 ) .EQ. CHAR( 0 ) )   ) THEN
                FDESC3D( L ) = 'Data interpolated from grid "' //
     &                         TRIM( IGRID ) //
     &                         '" to grid "' // TRIM( OGRID ) // '"'
                GO TO  11
            END IF
        END DO
11      CONTINUE        !  exit from loop


C...............  Allocate buffers; compute re-gridding matrix

        ALLOCATE( IBUF( NCOLS1,  NROWS1,  NLAYS3D ),
     &            OBUF( NCOLS3D, NROWS3D, NLAYS3D ),
     &            MASK( NROWSM ),
     &            CBUF( NROWSM + 2 * NCOLSM ),
     &            STAT = STATUS )

        IF ( STATUS .NE. 0 ) THEN
            WRITE( MESG, '( A, I10 )' )
     &               'Buffer allocation failed:  STAT=', STATUS
            CALL M3EXIT( PNAME, 0, 0, MESG, 2 )
        END IF


C...............  Open output file

        MESG  = 'Enter name for output data file'
        ONAME = PROMPTMFILE( MESG, FSUNKN3, 'OUT_DATA', PNAME )


C...............  Read the transform matrix and build the mask:

        IF ( .NOT.READ3( MNAME, 'ALL', 1, 0, 0, CBUF ) ) THEN
            MESG = 'Could not read transform matrix from ' // MNAME
            CALL M3EXIT( PNAME, 0, 0, MESG, 2 )
        END IF
        CALL MAKEMASK( NROWSM, NCOLSM,
     &                 CBUF, CBUF(NROWSM+1), CBUF(NCOLSM+NROWSM+1),
     &                 MASK )

C...............  Process output time step sequence

        DO  N = 1, NRECS

            IF ( SFLAG ) THEN
                IF ( .NOT. CHECK3( SNAME, SVBLE, JDATE, JTIME ) ) THEN
                    MESG = 'Failure checking variable "' //
     &                     TRIM( SVBLE ) // '" from synch file "' //
     &                     TRIM( SNAME ) // '"'
                    CALL M3EXIT( PNAME, 0, 0, MESG, 2 )
                END IF
            END IF

            WRITE( MESG, '( A, I7.7, A, I6.6 )' )
     &          'Processing  ', JDATE, ':', JTIME

            CALL M3MSG2( ' ' )
            CALL M3MSG2( MESG )

            DO  V = 1, NVARS3D  !  loop on variables

                IF ( .NOT. READ3( FNAME, VNAME3D( V ), ALLAYS3,
     &                            JDATE, JTIME, IBUF ) ) THEN
                    MESG = 'Failure reading variable "' //
     &                     TRIM( VNAME3D( V ) )
     &                     // '" from file "' //
     &                     TRIM( FNAME ) // '"'
                    CALL M3EXIT( PNAME, 0, 0, MESG, 2 )
                END IF

                IF ( .NOT. READ3( GNAME, VNAME3D( V ), ALLAYS3,
     &                            JDATE, JTIME, OBUF ) ) THEN
                    MESG = 'Failure reading variable "' //
     &                     TRIM( VNAME3D( V ) )
     &                     // '" from file "' //
     &                     TRIM( GNAME ) // '"'
                    CALL M3EXIT( PNAME, 0, 0, MESG, 2 )
                END IF

                CALL MASKVEC( NSIZE1, NROWSM, NLAYS3D, NCOLSM,
     &                        CBUF,
     &                        CBUF(NROWSM+1),
     &                        CBUF(NCOLSM+NROWSM+1),
     &                        IBUF, MASK, OBUF )

                IF ( .NOT.WRITE3( ONAME, VNAME3D( V ),
     &                            JDATE, JTIME, OBUF ) ) THEN
                    MESG = 'Failure writing variable "' //
     &                     TRIM( VNAME3D( V ) ) // '" to file "' //
     &                     TRIM( ONAME ) // '"'
                    CALL M3EXIT( PNAME, 0, 0, MESG, 2 )
                END IF

            END DO      !  end loop on variables


            CALL NEXTIME( JDATE, JTIME, TSTEP )

        END DO          !  end loop on output time steps


C...............  Successful completion

        CALL M3EXIT( PNAME, 0, 0,
     &               'Successful completion of program MTXBLENd', 0 )

        END PROGRAM MTXBLEND

C=======================================================================

        SUBROUTINE MAKEMASK( NROWS, NCOFF, N, I, M, MASK )

C***********************************************************************
C
C  FUNCTION:  Compute sum of coeffs at each output cell, and trap
C       against 0.0 and 1.0
C
C  PRECONDITIONS REQUIRED:  none
C
C  SUBROUTINES AND FUNCTIONS CALLED:  none
C
C  REVISION  HISTORY:
C       Adapted 11/2000 by CJC from I/O API "smatvec.f"
C
C***********************************************************************

        IMPLICIT NONE

C...........   ARGUMENTS and their descriptions:

        INTEGER         NROWS           ! length of output vector
        INTEGER         NCOFF           ! max number of coefficients

        INTEGER         N( NROWS )      ! # of entries per row
        INTEGER         I( NCOFF )      ! columns list
        REAL            M( NCOFF )      ! coefficient array

        REAL            MASK( NROWS )   ! output mask


C...........   SCRATCH LOCAL VARIABLES and their descriptions:

        INTEGER         R, C, K
        REAL            SUM

C***********************************************************************
C   begin body of subroutine  MAKEMASK

        K = 0
        DO  R = 1, NROWS

            SUM = 0.0

            DO  C = 1, N( R )
                K = K + 1
                SUM = SUM  +  M( K )
            END DO

            MASK( R ) = MIN( MAX( SUM, 0.0 ), 1.0 )

        END DO

        RETURN

        END SUBROUTINE MAKEMASK


C=======================================================================

        SUBROUTINE MASKVEC( NCOLS, NROWS, NLAYS, NCOFF, N, I, M,
     &                      U, P, V )

C***********************************************************************
C
C  FUNCTION:  multiply a sparse matrix <N,I,C> by a layered vector U and
C             do a masked-add of the layered result with V
C
C  PRECONDITIONS REQUIRED:  none
C
C  SUBROUTINES AND FUNCTIONS CALLED:  none
C
C  REVISION  HISTORY:
C       Adapted 9/2000 by CJC from I/O API "smatvec.f"
C
C***********************************************************************

        IMPLICIT NONE

C...........   ARGUMENTS and their descriptions:

        INTEGER         NCOLS           ! length of input vector
        INTEGER         NROWS           ! length of output vector
        INTEGER         NLAYS           ! number of layers in vectors
        INTEGER         NCOFF           ! max number of coefficients

        INTEGER         N( NROWS )      ! # of entries per row
        INTEGER         I( NCOFF )      ! columns list
        REAL            M( NCOFF )      ! coefficient array

        REAL            U( NCOLS, NLAYS )      !  input vector
        REAL            P( NROWS )             ! output-mask
        REAL            V( NROWS, NLAYS )      ! output vector


C...........   SCRATCH LOCAL VARIABLES and their descriptions:

        INTEGER         R, C, K, L
        REAL            SUM


C***********************************************************************
C   begin body of subroutine  MATVEC

        DO  L = 1, NLAYS

            K = 0
            DO  R = 1, NROWS

                IF ( N( R ) .GT. 0 ) THEN

                    SUM = 0.0
                    DO  C = 1, N( R )
                        K = K + 1
                        SUM = SUM  +  M( K ) * U( I( K ), L )
                    END DO

                    IF ( SUM .GT. 0.0 ) THEN
                        V(R,L) = P(R) * SUM + (1.0 - P(R)) * V(R,L)
                    END IF

                END IF

            END DO

        END DO

        RETURN

        END SUBROUTINE MASKVEC

