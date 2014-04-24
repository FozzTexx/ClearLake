/* Copyright 2008 by Traction Systems, LLC. <http://tractionsys.com/>
 *
 * This file is part of ClearLake.
 *
 * ClearLake is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 3, or (at your option) any later
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

#import "Header.h"

#include <ctype.h>
#include <stdlib.h>
#include <string.h>

@implementation Header

- init
{
  [super init];
  headers = malloc(1);
  mbuf = malloc(1);
  headers[0] = mbuf[0] = 0;
  
  return self;
}

- initFromString:(const char *) str
{
  return [self initFromString:str length:strlen(str)];
}

- initFromString:(const char *) str length:(unsigned int) len
{
  char *p;

  
  [self init];

  if (headers)
    headers = realloc(headers, len+2);
  else
    headers = malloc(len+2);
  strncpy(headers, str, len);
  headers[len] = 0;
  strcat(headers, "\n");
  if ((p = strstr(headers, "\n\n")))
    *(p+1) = 0;
  if (*headers == '\n')
    *headers = 0;
  mbuf = realloc(mbuf, strlen(headers) + 1);
  
  return self;
}

-(void) dealloc
{
  if (headers)
    free(headers);
  if (mbuf)
    free(mbuf);

  [super dealloc];
  return;
}

- copy
{
  self = [super copy];
  if (headers)
    headers = strdup(headers);
  if (mbuf)
    mbuf = strdup(headers); /* Yes, headers. Could be a NULL too soon in mbuf */
  
  return self;
}

- writeSelf:(CLStream *) stream
{
  [stream write:headers length:strlen(headers)];
  return self;
}

- setHeaders:(const char *) str
{
  return [self setHeaders:str length:strlen(str)];
}

- setHeaders:(const char *) str length:(unsigned int) len
{
  char *p;

  
  if (headers)
    headers = realloc(headers, len+2);
  else
    headers = malloc(len+2);
  strncpy(headers, str, len);
  headers[len] = 0;
  strcat(headers, "\n");
  if ((p = strstr(headers, "\n\n")))
    *(p+1) = 0;
  if (*headers == '\n')
    *headers = 0;
  
  if (mbuf)
    mbuf = realloc(mbuf, len+1);
  else
    mbuf = malloc(len+1);
  
  return self;
}

-(char *) headerStart:(const char *) hstr past:(char *) pos
{
  char *p;
  int fm;
  

  fm = !strcmp(hstr, "From ");
  if (!fm && strpbrk(hstr, " \t\n")) /* Can't have these characters in header string */
    return NULL;

  if (!pos)
    p = headers;
  else
    p = pos;
  
  while (p && *p) {
    if (!strncasecmp(p, hstr, strlen(hstr)) && (fm || p[strlen(hstr)] == ':'))
      return p;
    
    p = strchr(p, '\n');
    if (p)
      p++;
  }

  return NULL;
}

-(char *) headerEnd:(const char *) hstr past:(char *) pos
{
  char *p;


  if (!pos) {
    p = [self headerStart:hstr past:NULL];
    if (p)
      p += strlen(hstr) + 1;
  }
  else
    p = pos;
  
  if (!p)
    return NULL;

  do {
    for (; *p != '\n'; p++);
    p++;
  } while (*p == ' ' || *p == '\t');

  return p;
}

-(const char *) valueOf:(const char *) hstr
{
  char *p, *q;
  int i;
  

  if (![self headerStart:hstr past:NULL])
    return NULL;

  q = NULL;
  mbuf[0] = 0;
  while ((p = [self headerStart:hstr past:q])) {
    p += strlen(hstr) + 1;
    while (*p == ' ' || *p == '\t')
      p++;
  
    q = [self headerEnd:hstr past:p];

    if (mbuf[0])
      strcat(mbuf, "\n");
    
    i = strlen(mbuf);
    strncat(mbuf, p, q - p);
    mbuf[i + (q - p)] = 0;

    for (p = mbuf + i; *p; p++)
      while (*p == '\n')
	strcpy(p, p+1);
  }
  
  return mbuf;
}

- addHeader:(const char *) hstr withValue:(const char *) str
{
  char *p, *q;
  int fm;
  

  fm = !strcmp(hstr, "From ");
  if ((p = [self headerStart:hstr past:NULL]))
    q = [self headerEnd:hstr past:p];
  else if (fm) /* Gotta make "From " first header */
    p = q = headers;
  else
    p = q = headers + strlen(headers);

  while (str && isspace(*str))
    str++;
  
  if (str) {
    mbuf = realloc(mbuf, strlen(headers) - (q - p) + strlen(hstr) + strlen(str) + 4);
    strncpy(mbuf, headers, p - headers);
    mbuf[p-headers] = 0;
    strcat(mbuf, hstr);
    if (!fm)
      strcat(mbuf, ": ");
    strcat(mbuf, str);
    strcat(mbuf, "\n");
    strcat(mbuf, q);
    free(headers);
    headers = strdup(mbuf);
  }
  else {
    mbuf = realloc(mbuf, strlen(headers) - (q - p) + 1);
    strncpy(mbuf, headers, p - headers);
    mbuf[p-headers] = 0;
    strcat(mbuf, q);
    free(headers);
    headers = strdup(mbuf);
  }    
  
  return self;
}

- deleteHeader:(const char *) hstr
{
  return [self addHeader:hstr withValue:NULL];
}

-(CLUInteger) count
{
  int i;
  char *p;


  p = headers;
  i = 0;
  while ((p = strchr(p, '\n'))) {
    p++;
    if (!isspace(*p))
      i++;
  }

  return i;
}

-(const char *) headerAt:(int) index
{
  int i;
  char *p, *q;

  
  if (index >= [self count])
    return NULL;

  p = headers;
  i = 0;
  for (; p;) {
    if (i == index) {
      q = strchr(p, ':');
      strncpy(mbuf, p, q-p);
      mbuf[q-p] = 0;
      return mbuf;
    }

    p = strchr(p, '\n');
    p++;
    if (!isspace(*p))
      i++;
  }
  
  return NULL;
}

@end
