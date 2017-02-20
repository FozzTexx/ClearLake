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

#import "CLClassConstants.h"
#import "CLAccount.h"
#import "CLArray.h"
#import "CLAttribute.h"
#import "CLButton.h"
#import "CLCategory.h"
#import "CLChainedSelect.h"
#import "CLCharacterSet.h"
#import "CLMutableCharacterSet.h"
#import "CLControl.h"
#import "CLForm.h"
#import "CLData.h"
#import "CLMutableData.h"
#import "CLDatetime.h"
#import "CLDecimalNumber.h"
#import "CLDictionary.h"
#import "CLEditingContext.h"
#import "CLRecordDefinition.h"
#import "CLFault.h"
#import "CLArrayFault.h"
#import "CLElement.h"
#import "CLBlock.h"
#import "CLScriptElement.h"
#import "CLGenericRecord.h"
#import "CLImageElement.h"
#import "CLInput.h"
#import "CLMutableArray.h"
#import "CLMutableDictionary.h"
#import "CLNumber.h"
#import "CLOption.h"
#import "CLPage.h"
#import "CLPageTarget.h"
#import "CLRangeView.h"
#import "CLPager.h"
#import "CLPlaceholder.h"
#import "CLRangeView.h"
#import "CLRelationship.h"
#import "CLScriptElement.h"
#import "CLSelect.h"
#import "CLSession.h"
#import "CLSplitter.h"
#import "CLStandardContent.h"
#import "CLStandardContentFile.h"
#import "CLOriginalFile.h"
#import "CLOriginalImage.h"
#import "CLCachedImage.h"
#import "CLStandardContentImage.h"
#import "CLStandardContentCategory.h"
#import "CLFileType.h"
#import "CLString.h"
#import "CLUTF8String.h"
#import "CLConstantString.h"
#import "CLConstantUnicodeString.h"
#import "CLMutableString.h"
#import "CLTextArea.h"
#import "CLWikiImage.h"
#import "CLWikiLink.h"
#import "CLWikiMedia.h"
#import "CLWikiString.h"
#import "CLStackString.h"

Class CLInputClass;
Class CLImageElementClass;
Class CLDatetimeClass;
Class CLControlClass, CLFormClass;
Class CLSessionClass, CLAccountClass;
Class CLSelectClass;
Class CLArrayClass, CLMutableArrayClass;
Class CLButtonClass;
Class CLCharacterSetClass, CLMutableCharacterSetClass;
Class CLDataClass, CLMutableDataClass;
Class CLDictionaryClass, CLMutableDictionaryClass;
Class CLEditingContextClass, CLGenericRecordClass, CLAttributeClass, CLRelationshipClass,
  CLRecordDefinitionClass, CLFaultClass, CLArrayFaultClass, CLPlaceholderClass;
Class CLElementClass, CLBlockClass, CLOptionClass, CLScriptElementClass,
  CLRangeViewClass, CLSplitterClass, CLPagerClass, CLChainedSelectClass;
Class CLNumberClass, CLDecimalNumberClass;
Class CLPageClass, CLPageTargetClass;
Class CLStandardContentClass, CLCategoryClass, CLStandardContentCategoryClass,
  CLStandardContentFileClass, CLStandardContentImageClass, CLOriginalFileClass,
  CLOriginalImageClass, CLCachedImageClass, CLFileTypeClass;
Class CLStringClass, CLUTF8StringClass, CLConstantStringClass, CLConstantUnicodeStringClass,
  CLMutableStringClass, CLMutableStackStringClass, CLImmutableStackStringClass;
Class CLTextAreaClass;
Class CLWikiStringClass, CLWikiImageClass, CLWikiMediaClass, CLWikiLinkClass;

/* Linker is wacky, these have to be in a certain order */
int CLInitClassConstants()
{
  static int doingInit = NO;
  static int initStage = 0;
  

  if (!doingInit) {
    doingInit = YES;

    switch (initStage) {
    case 0:
      CLAccountClass = [CLAccount class];
      CLArrayClass = [CLArray class];
      CLAttributeClass = [CLAttribute class];
      CLBlockClass = [CLBlock class];
      CLButtonClass = [CLButton class];
      CLChainedSelectClass = [CLChainedSelect class];
      CLCharacterSetClass = [CLCharacterSet class];
      CLConstantStringClass = [CLConstantString class];
      CLControlClass = [CLControl class];
      CLDataClass = [CLData class];
      CLDatetimeClass = [CLDatetime class];
      CLDecimalNumberClass = [CLDecimalNumber class];
      CLDictionaryClass = [CLDictionary class];
      CLElementClass = [CLElement class];
      CLFormClass = [CLForm class];
      CLGenericRecordClass = [CLGenericRecord class];
      CLImageElementClass = [CLImageElement class];
      CLInputClass = [CLInput class];
      CLMutableArrayClass = [CLMutableArray class];
      CLMutableCharacterSetClass = [CLMutableCharacterSet class];
      CLMutableDataClass = [CLMutableData class];
      CLMutableDictionaryClass = [CLMutableDictionary class];
      CLMutableStringClass = [CLMutableString class];
      CLNumberClass = [CLNumber class];
      CLOptionClass = [CLOption class];
      CLPageClass = [CLPage class];
      CLPageTargetClass = [CLPageTarget class];
      CLPagerClass = [CLPager class];
      CLPlaceholderClass = [CLPlaceholder class];
      CLRangeViewClass = [CLRangeView class];
      CLRangeViewClass = [CLRangeView class];
      CLRelationshipClass = [CLRelationship class];
      CLSelectClass = [CLSelect class];
      CLSessionClass = [CLSession class];
      CLStringClass = [CLString class];
      CLTextAreaClass = [CLTextArea class];
      CLUTF8StringClass = [CLUTF8String class];
      break;

    case 1:
      break;
      
    case 2:
      CLStandardContentImageClass = [CLStandardContentImage class];
      CLStandardContentCategoryClass = [CLStandardContentCategory class];
      CLSplitterClass = [CLSplitter class];
      CLRecordDefinitionClass = [CLRecordDefinition class];
      CLFileTypeClass = [CLFileType class];
      CLFaultClass = [CLFault class];
      CLEditingContextClass = [CLEditingContext class];
      CLArrayFaultClass = [CLArrayFault class];
      CLCachedImageClass = [CLCachedImage class];
      CLCategoryClass = [CLCategory class];
      CLConstantUnicodeStringClass = [CLConstantUnicodeString class];
      CLImmutableStackStringClass = [CLImmutableStackString class];
      CLMutableStackStringClass = [CLMutableStackString class];
      CLOriginalFileClass = [CLOriginalFile class];
      CLOriginalImageClass = [CLOriginalImage class];
      CLScriptElementClass = [CLScriptElement class];
      CLStandardContentClass = [CLStandardContent class];
      CLStandardContentFileClass = [CLStandardContentFile class];
      CLWikiImageClass = [CLWikiImage class];
      CLWikiLinkClass = [CLWikiLink class];
      CLWikiMediaClass = [CLWikiMedia class];
      CLWikiStringClass = [CLWikiString class];
      break;

    default:
      return 1;
    }

    initStage++;
    doingInit = NO;
  }

  return 0;
}
