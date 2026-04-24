/* Copyright 2026 by
 *   Chris Osborn <fozztexx@fozztexx.com>
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

#ifndef _CLPOSTGRESDATABASE_H
#define _CLPOSTGRESDATABASE_H

#import <ClearLake/CLDatabase.h>

#include <postgresql/libpq-fe.h>

@interface CLPostgresDatabase:CLDatabase <CLDatabaseMethods>
{
  PGconn *conn;
}

-(id) initWithDatabase:(CLString *) aDatabase user:(CLString *) user
              password:(CLString *) password host:(CLString *) aHost;
-(void) dealloc;
-(id) runQuery:(CLString *) aQuery;

@end

#endif /* _CLPOSTGRESDATABASE_H */
