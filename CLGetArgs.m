/* Copyright 2008-2016 by
 *   Chris Osborn <fozztexx@fozztexx.com>
 *   Rob Watts <rob@rawatts.com>
 *
 * This file is part of ClearLake.
 *
 * ClearLake is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2.1, or (at your option) any later
 * version.
 *
 * ClearLake is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
 * for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with ClearLake; see the file COPYING. If not see
 * <http://www.gnu.org/licenses/>.
 */

#import "CLGetArgs.h"
#import "CLString.h"

#include <stdarg.h>
#include <stdlib.h>

/***********************************************************************

		   Based on getargs.c from fozzlib
  
		 Copyright 1991-2011 by Chris Osborn
			fozztexx@fozztexx.com
  

  This function will read the flags from the command line and fill the
  variables that are passed with the appropriate values, if the
  specified flag was on the command line.

  It will return the number of the first non-flag-related argument, or
  else -(bad flag) if a flag that wasn't in the format string was
  present, or a flag requiring an argument didn't have one.

  If an unknown flag is encountered, processing will be aborted, and
  the return will be a negative number which is equal to -(bad flag).
  I designed it this way ON PURPOSE to try to force the programmer to
  spit out some help instead of ignoring the bad flag.

  Flags may be specified seperately, as in
    -a -b H -c 25 -d Hello
  or all together, as in
    -abcd H 25 Hello
  or even mixed, like
    -abc H 25 -d Hello
   
  You need to pass it argc, argv, a format string, and all the
  pointers to variables.

  The structure of the format string is flag, type. The string
     "AbQi"
  specifies that flag "A" is a boolean, and flag "Q" is of type int.
  
  If any of the flags are not present in the passed argv, the contents
  of the corresponding variable will not be changed.

  Supported types are
     b: boolean, sets var (BOOL) to 1 if flag exists
     o: order, sets var (CLInteger) to order of flag relative
          to other "order" flags on command line
     c: char, sets var (CLInteger) first char of next arg
     s: string, creates CLString from next arg
     i: int, uses atoi on next arg
     d: double, uses atof on next arg
     f: calls function with flag and arg pointer,
          function must return number of args used

***********************************************************************/

CLInteger CLGetArgs(int argc, char **argv, CLString *format, ...)
{
  va_list ap;
  int count, i, j, k;
  int order = 0;
  int **arg;
  char **na;
  int nf;
  int (*mf)();
  unichar *buf;
  int result = 0;
#if DEBUG_LEAK
  id self = nil;
#endif
  

  va_start(ap, format);
  count = argc;

  i = [format length];
  buf = calloc(i+2, sizeof(unichar));
  [format getCharacters:buf];
  arg = malloc(sizeof(void *) * (i / 2));
  for (i = 0; buf[i]; i += 2)
    arg[i / 2] = va_arg(ap, void *);

  for (argc--, na = ++argv, na++; !result && argc && **argv == '-'; argc--, argv = na, na++)
    for ((*argv)++; !result && **argv; (*argv)++) {
      for (nf = 0, i = 0; !result && buf[i]; i += 2)
	if (buf[i] == **argv) {
	  nf++;
	  switch (buf[i + 1]) {
	  case 'b':
	    *((BOOL *) arg[i / 2]) = 1;
	    break;

	  case 'o':
	    order++;
	    *((CLInteger *) arg[i / 2]) = order;
	    break;
	  
	  case 'c':
	    argc--;
	    if (!argc)
	      result = -(**argv);
	    else {
	      *((CLInteger *) arg[i / 2]) = **na;
	      na++;
	    }
	    break;

	  case 's':
	    argc--;
	    if (!argc)
	      result = -(**argv);
	    else {
	      *((CLString **) arg[i / 2]) = [CLString stringWithUTF8String:(char *) *na];
	      na++;
	    }
	    break;

	  case 'i':
	    argc--;
	    if (!argc)
	      result = -(**argv);
	    else {
	      *((int *) arg[i / 2]) = atoi(*na);
	      na++;
	    }
	    break;

	  case 'd':
	    argc--;
	    if (!argc)
	      result = -(**argv);
	    else {
	      *((double *) arg[i / 2]) = atof(*na);
	      na++;
	    }
	    break;

	  case 'f':
	    argc--;
	    if (!argc)
	      result = -(**argv);
	    else {
	      mf = (void *) arg[i / 2];
	      j = mf((int) buf[i], na);
	      for (k = 0; k < j; k++, na++)
		;
	    }
	    break;
	  }
	}
      
      if (!nf)
	result = -(**argv);
    }

  va_end(ap);
  free(arg);
  free(buf);

  if (!result)
    result = count - argc;
  return result;
}
