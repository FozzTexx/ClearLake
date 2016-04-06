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

#import "CLExpression.h"
#import "CLString.h"
#import "CLMutableCharacterSet.h"
#import "CLMutableArray.h"
#import "CLMutableString.h"
#import "CLNumber.h"

#include <wctype.h>

typedef enum {
  CLOperandOperator = 0,
  CLParenLeftOperator,
  CLParenRightOperator,
  CLLogicalNotOperator,
  CLLogicalAndOperator,
  CLLogicalOrOperator,
} CLOperator;

struct {
  CLOperator op;
  int precedence;
  CLString *string;
} CLOperations[] = {
  /* Ordered by string length */
  {CLLogicalAndOperator, 4, @"&&"},
  {CLLogicalOrOperator, 3, @"||"},
  {CLParenLeftOperator, 0, @"("},
  {CLParenRightOperator, 0, @")"},
  {CLLogicalNotOperator, 14, @"!"},
  {0, 0, nil}
};
  
@implementation CLExpression

-(id) init
{
  return [self initFromString:nil];
}

-(id) initFromString:(CLString *) aString
{
  [super init];
  operator = precedence = 0;
  left = right = nil;

  if (aString)
    [self parseString:aString];
  
  return self;
}

-(void) dealloc
{
  [left release];
  [right release];
  [super dealloc];
  return;
}

-(id) evaluate:(id) anObject success:(BOOL *) success
{
  id aValue = nil;
  int val;

  
  switch (operator) {
  case CLOperandOperator:
    aValue = [anObject valueForExpression:left success:success];
    break;
    
  case CLLogicalNotOperator:
    aValue = [left evaluate:anObject success:success];
    if ([aValue isKindOfClass:CLNumberClass])
      val = [aValue boolValue];
    else
      val = !!aValue;
    aValue = [CLNumber numberWithBool:!val];
    break;

  case CLLogicalOrOperator:
    aValue = [left evaluate:anObject success:success];
    if ([aValue isKindOfClass:CLNumberClass])
      val = [aValue boolValue];
    else
      val = !!aValue;
    aValue = [CLNumber numberWithBool:val];
    if (![aValue boolValue]) {
      aValue = [right evaluate:anObject success:success];
      if ([aValue isKindOfClass:CLNumberClass])
	val = [aValue boolValue];
      else
	val = !!aValue;
      aValue = [CLNumber numberWithBool:val];
    }
    break;

  case CLLogicalAndOperator:
    aValue = [left evaluate:anObject success:success];
    if ([aValue isKindOfClass:CLNumberClass])
      val = [aValue boolValue];
    else
      val = !!aValue;
    aValue = [CLNumber numberWithBool:val];
    if ([aValue boolValue]) {
      aValue = [right evaluate:anObject success:success];
      if ([aValue isKindOfClass:CLNumberClass])
	val = [aValue boolValue];
      else
	val = !!aValue;
      aValue = [CLNumber numberWithBool:val];
    }
    break;
  }
    
  return aValue;
}

-(void) parseOperator:(CLExpression *) anExp operatorStack:(CLMutableArray *) operatorStack
	 operandStack:(CLMutableArray *) operandStack
{
  id aLeft = nil, aRight = nil;

  
  switch ([anExp operator]) {
  case CLLogicalNotOperator:
    aLeft = [[operandStack lastObject] retain];
    [operandStack removeLastObject];
    break;
		
  default:
    aRight = [[operandStack lastObject] retain];
    [operandStack removeLastObject];
    aLeft = [[operandStack lastObject] retain];
    [operandStack removeLastObject];
    break;
  }

  [anExp setLeft:aLeft];
  [anExp setRight:aRight];
  [operandStack addObject:anExp];
  [aLeft release];
  [aRight release];

  return;
}

-(void) parseString:(CLString *) aString
{
  CLCharacterSet *operandSet;
  CLRange aRange;
  int i, j, k;
  unichar c;
  CLString *anOperand;
  CLMutableArray *operandStack, *operatorStack;
  CLExpression *anExp, *anExp2;


  operandSet = [CLCharacterSet characterSetWithCharactersInString:@"|&()!"];

  operandStack = [[CLMutableArray alloc] init];
  operatorStack = [[CLMutableArray alloc] init];
  
  for (i = 0, j = [aString length]; i < j; i++) {
    c = [aString characterAtIndex:i];
    if (iswspace(c))
      continue;
    
    if (![operandSet characterIsMember:c]) {
      aRange = [aString rangeOfCharacterFromSet:operandSet options:0
			range:CLMakeRange(i, j - i)];
      if (!aRange.length)
	aRange.location = j;
      anOperand = [aString substringWithRange:CLMakeRange(i, aRange.location - i)];
      i = aRange.location - 1;

      anExp = [[CLExpression alloc] init];
      [anExp setOperator:CLOperandOperator];
      [anExp setPrecedence:0];
      [anExp setLeft:anOperand];
      [operandStack addObject:anExp];
      [anExp release];
    }
    else {
      aRange.location = i;
      for (k = 0; CLOperations[k].op; k++) {
	aRange.length = [CLOperations[k].string length];
	if (CLMaxRange(aRange) <= j &&
	    ![aString compare:CLOperations[k].string options:0 range:aRange]) {
	  i = CLMaxRange(aRange) - 1;

	  anExp = [[CLExpression alloc] init];
	  [anExp setOperator:CLOperations[k].op];
	  [anExp setPrecedence:CLOperations[k].precedence];
	  
	  if ([anExp operator] != CLParenRightOperator &&
	      (![operatorStack count] ||
	       [[operatorStack lastObject] precedence] < [anExp precedence] ||
	       [anExp operator] == CLParenLeftOperator))
	    [operatorStack addObject:anExp];
	  else {
	    if ([anExp operator] == CLParenRightOperator) {
	      anExp2 = [[operatorStack lastObject] retain];
	      [operatorStack removeLastObject];
	      while ([anExp2 operator] != CLParenLeftOperator) {
		[self parseOperator:anExp2 operatorStack:operatorStack
		      operandStack:operandStack];
		[anExp2 release];
		anExp2 = [[operatorStack lastObject] retain];
		[operatorStack removeLastObject];		
	      }
	      [anExp2 release];
	    }
	    else {
	      anExp2 = [[operatorStack lastObject] retain];
	      [operatorStack removeLastObject];		
	      [operatorStack addObject:anExp];
	      [self parseOperator:anExp2 operatorStack:operatorStack
		    operandStack:operandStack];
	      [anExp2 release];
	    }
	  }
	  
	  [anExp release];
	  break;
	}
      }
    }
  }

  while ([operatorStack count]) {
    anExp = [[operatorStack lastObject] retain];
    [operatorStack removeLastObject];
    [self parseOperator:anExp operatorStack:operatorStack operandStack:operandStack];
    [anExp release];
  }

  anExp = [operandStack lastObject];
  [self setOperator:[anExp operator]];
  [self setPrecedence:[anExp precedence]];
  [self setLeft:[anExp left]];
  [self setRight:[anExp right]];
  
  [operandStack release];
  [operatorStack release];
  
  return;
}

-(CLUInteger) operator
{
  return operator;
}

-(CLUInteger) precedence
{
  return precedence;
}

-(id) left
{
  return left;
}

-(id) right
{
  return right;
}

-(void) setOperator:(CLUInteger) aValue
{
  operator = aValue;
  return;
}

-(void) setPrecedence:(CLUInteger) aValue
{
  precedence = aValue;
  return;
}

-(void) setLeft:(id) anObject
{
  if (left != anObject) {
    [left release];
    left = [anObject retain];
  }
  return;
}
    
-(void) setRight:(id) anObject
{
  if (right != anObject) {
    [right release];
    right = [anObject retain];
  }
  return;
}

-(CLString *) description
{
  CLMutableString *mString;
  int i;


  for (i = 0; CLOperations[i].op; i++)
    if (CLOperations[i].op == operator)
      break;

  mString = [CLMutableString stringWithString:CLOperations[i].string];

  switch (operator) {
  case CLOperandOperator:
    [mString appendString:[left description]];
    break;
    
  case CLLogicalNotOperator:
    [mString appendString:@" : "];
    [mString appendString:[left description]];
    break;

  default:
    [mString appendString:@" : "];
    [mString appendString:[right description]];
    [mString appendString:@"\n"];
    [mString appendString:@" : "];
    [mString appendString:[left description]];
    break;
  }

  [mString appendString:@"\n"];
  
  return mString;
}

@end
