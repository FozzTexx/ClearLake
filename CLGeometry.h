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

#import <ClearLake/CLRuntime.h>

typedef struct {
  float width, height;
} CLSize;

typedef struct {
  float x, y;
} CLPoint;

typedef struct {
  CLPoint origin;
  CLSize size;
} CLRect;

CL_INLINE CLSize CLMakeSize(float w, float h)
{
  CLSize s;

  
  s.width = w;
  s.height = h;
  return s;
}

CL_INLINE CLPoint CLMakePoint(float x, float y)
{
  CLPoint p;

  
  p.x = x;
  p.y = y;
  return p;
}

CL_INLINE CLRect CLMakeRect(float x, float y, float w, float h)
{
  CLRect r;


  r.origin.x = x;
  r.origin.y = y;
  r.size.width = w;
  r.size.height = h;
  return r;
}
