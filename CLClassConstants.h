/* Copyright 2016 by Chris Osborn <fozztexx@fozztexx.com>
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

#ifndef _CLCLASSCONSTANTS_H
#define _CLCLASSCONSTANTS_H

extern Class CLSelectClass;
extern Class CLInputClass;
extern Class CLImageElementClass;
extern Class CLDatetimeClass;
extern Class CLControlClass, CLFormClass;
extern Class CLSessionClass, CLAccountClass;
extern Class CLArrayClass, CLMutableArrayClass;
extern Class CLButtonClass;
extern Class CLCharacterSetClass, CLMutableCharacterSetClass;
extern Class CLDataClass, CLMutableDataClass;
extern Class CLDictionaryClass, CLMutableDictionaryClass;
extern Class CLEditingContextClass, CLGenericRecordClass, CLAttributeClass,
  CLRelationshipClass, CLRecordDefinitionClass, CLFaultClass, CLArrayFaultClass,
  CLPlaceholderClass;
extern Class CLElementClass, CLBlockClass, CLOptionClass,
  CLRangeViewClass, CLSplitterClass, CLPagerClass, CLChainedSelectClass;
extern Class CLNumberClass, CLDecimalNumberClass;
extern Class CLPageClass, CLPageTargetClass;
extern Class CLStandardContentCategoryClass, CLStandardContentImageClass, CLFileTypeClass;
extern Class CLStringClass, CLUTF8StringClass, CLConstantStringClass, CLMutableStringClass;
extern Class CLTextAreaClass;

/* The linker has a hard time finding these for some reason */
#if 1
extern Class CLCachedImageClass, CLCategoryClass, CLConstantUnicodeStringClass,
  CLMutableStackStringClass, CLOriginalFileClass,
  CLOriginalImageClass, CLScriptElementClass, CLStandardContentClass,
  CLStandardContentFileClass, CLWikiImageClass, CLWikiLinkClass, CLWikiMediaClass, CLWikiStringClass;
extern Class CLImmutableStackStringClass;
#endif

extern void initClassConstants();

#endif /* _CLCLASSCONSTANTS_H */
