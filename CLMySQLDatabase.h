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

#import <ClearLake/CLDatabase.h>

/* Must undef and redef alloc because MySQL used it as a struct member */
#if DEBUG_RETAIN
#undef alloc
#endif

#include <mysql/mysql.h>

#if DEBUG_RETAIN
#define alloc		alloc:__FILE__ :__LINE__ :self
#endif

@interface CLMySQLDatabase:CLDatabase <CLDatabaseMethods>
{
  MYSQL *conn;
}

-(id) initWithDatabase:(CLString *) aDatabase user:(CLString *) user
	      password:(CLString *) password host:(CLString *) aHost;
-(void) dealloc;
-(id) runQuery:(CLString *) aQuery;

@end
