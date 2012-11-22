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

#import "CLChainedSelect.h"
#import "CLOption.h"
#import "CLArray.h"
#import "CLField.h"
#import "CLNumber.h"
#import "CLMutableDictionary.h"

#if 0
static CLString *jsBlock =
#include "CLChainedSelect.jh"
  ;
#endif

@implementation CLChainedSelect

-(int) insertOptions:(CLArray *) anArray parent:(CLOption *) parentOpt
		name:(CLString *) name other:(CLString *) otherValue
{
  int i, j;
  CLOption *anOption;
  int depth = 0, ndepth;
  id parentList, subList;


  if (parentOpt) {
    if (!(parentList = [parentOpt value]))
      parentList = [parentOpt string];
    parentList = [CLString stringWithFormat:@"%@-%u", name, [parentList hash]];
  }
  else
    parentList = name;
  for (i = 0, j = [anArray count]; i < j; i++) {
    anOption = [anArray objectAtIndex:i];
    if ([[anOption subOptions] count]) {
      if (!(subList = [anOption value]))
	subList = [anOption string];
      subList = [CLString stringWithFormat:@"%@-%u", name, [subList hash]];
      [javascript addObject:[CLString stringWithFormat:
					@"addList('%@', '%@', '%@', '%@'%@);\n",
				      parentList,
				      [[anOption string]
					stringByReplacingOccurrencesOfString:@"'"
					withString:@"\\'"],
				      [[[anOption value] description]
					stringByReplacingOccurrencesOfString:@"'"
					withString:@"\\'"], subList,
				      [anOption selected] ? @", 1" : @""]];
      ndepth = [self insertOptions:[anOption subOptions] parent:anOption
		     name:name other:otherValue];
      if (ndepth > depth)
	depth = ndepth;
    }
    else
      [javascript addObject:
		    [CLString stringWithFormat:@"addOption('%@', '%@', '%@'%@);\n",
			      parentList, [[anOption string]
					    stringByReplacingOccurrencesOfString:@"'"
					    withString:@"\\'"],
			      [[[anOption value] description]
				stringByReplacingOccurrencesOfString:@"'"
				withString:@"\\'"],
			      [anOption selected] ? @", 1" : @""]];
  }

#if 0
  if (parentOpt)
    [javascript addObject:
		  [CLString stringWithFormat:@"addOption('%@', '-', '0');\n", parentList]];
  if (otherValue)
    [javascript addObject:
		  [CLString stringWithFormat:@"addOption('%i', 'Other:', '%@');\n",
			    parentOpt, otherValue]];
#endif

  return depth + 1;
}

-(CLOption *) defaultOption:(CLArray *) anArray
{
  CLOption *anOption;
  int i, j;


  for (i = 0, j = [anArray count]; i < j; i++) {
    anOption = [anArray objectAtIndex:i];
    if ([anOption selected])
      return anOption;
  }

  if ([anArray count])
    return [anArray objectAtIndex:0];

  return nil;
}

-(void) writeHTML:(CLStream *) stream
{
  int i;
  int depth;
  CLArray *anArray;
  CLString *name;
  CLString *otherValue;


  name = [attributes objectForCaseInsensitiveString:@"NAME"];
  if (!name)
    name = [CLString stringWithFormat:@"CL%u", (unsigned) self];
  otherValue = [attributes objectForCaseInsensitiveString:@"CL_OTHER"];

  javascript = [[CLBlock alloc] init];
  levelBlock = [[CLBlock alloc] init];
  
  [javascript addObject:@"<script><!--\n"];
  [javascript addObject:@"var hide_empty_list=true;\n"];
  [javascript addObject:[CLString stringWithFormat:@"addListGroup('%@', '%@');\n",
				  name, name]];

  anArray = [self value];
  depth = [self insertOptions:anArray parent:nil name:name other:otherValue];
  [levelBlock addObject:[CLField hiddenFieldNamed:
				   [CLString stringWithFormat:@"%@_depth", name]
				 withValue:[CLNumber numberWithInt:depth]]];

  for (i = 0; i < depth; i++)
    [levelBlock addObject:[CLString stringWithFormat:
				      @"<select id=%@_%i name=%@_%i></select>",
				    name, i+1, name, i+1]];

  if (otherValue) {
    CLField *aField;

    
    aField = [CLField textFieldNamed:[CLString stringWithFormat:@"%@_other", name]
		      withValue:nil];
    [[aField attributes] setObject:[CLString stringWithFormat:@"%@_other", name]
			 forKey:@"id"];
    [levelBlock addObject:aField];
#if 0
    [[aField attributes] setObject:@"assembleFullPath();" forKey:@"onkeyup"];
    [[aField attributes] setObject:@"assembleFullPath();" forKey:@"onchange"];
#endif
  }

#if 0
  [javascript addObject:
		[CLString stringWithFormat:
			    @"function assembleFullPath() {\n"
			  "  var depth = %i;\n"
			  "  var i;\n"
			  "  var title = '';\n"
			  "  var button = document.getElementById('join_category');\n"
			  "  var other = document.getElementById('%@_other');\n"
			  "\n"
			  "  for (i = 0; i < depth; i++) {\n"
			  "    var list = document.getElementById('level'+(i+1));\n"
			  "    if (list.style.display == 'none' ||\n"
			  "        list.options[list.selectedIndex].value <= 0)\n"
			  "      break;\n"
			  "    if (title.length)\n"
			  "      title = title+' > ';\n"
			  "    title = title+list.options[list.selectedIndex].text;\n"
			  "  }\n"
			  "\n"
			  "  if (other.style.display == '') {\n"
			  "    if (title.length)\n"
			  "      title = title+' > ';\n"
			  "    title = title+other.value;\n"
			  "  }\n"
			  "\n"
			  "  button.value = 'Join '+title;\n"
			  "}\n"
			  , depth, name]];
#endif
  if (otherValue) 
    [javascript addObject:
		  [CLString stringWithFormat:
			      @"function %@_showOtherField(list, order, instance, value) {\n"
			    "  var element = document.getElementById('%@_other');\n"
			    "  if (value == '%@')\n"
			    "    element.style.display='';\n"
			    "  else\n"
			    "    element.style.display='none';\n"
#if 0
			    "  assembleFullPath();\n"
#endif
			    "}\n", name, name, otherValue]];
  
  [javascript addObject:[CLString stringWithFormat:@"function %@_catChooserLoad() {\n",
			 name]];
  [javascript addObject:[CLString stringWithFormat:@"  initListGroup('%@'", name]];
  for (i = 0; i < depth; i++)
    [javascript addObject:[CLString stringWithFormat:@", document.theForm.%@_%i",
				    name, i+1]];
  if (otherValue)
    [javascript addObject:[CLString stringWithFormat:@", %@_showOtherField", name]];
  [javascript addObject:@");\n"];
  if (otherValue && ![[[[self defaultOption:anArray] value] description] isEqual:otherValue])
    [javascript addObject:[CLString stringWithFormat:
				      @"  document.theForm.%@_other.style.display='none';\n",
				    name]];
#if 0
  [javascript addObject:@"  assembleFullPath();\n"];
#endif
  [javascript addObject:@"}\n"];

  [javascript addObject:[CLString stringWithFormat:@"CLAddLoadEvent(%@_catChooserLoad);\n",
			 name]];
  
  [javascript addObject:@"--></script>\n"];

  [javascript addObject:levelBlock];
  [levelBlock release];
  CLWriteHTMLObject(stream, javascript);
  [javascript release];  
  return;
}

@end
