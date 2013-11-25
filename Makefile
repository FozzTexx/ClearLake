PRODUCT= libClearLake.a
# If PRODUCT= line is missing, be sure to insert one
# $(PRODUCT).c will be automatically compiled, so it
# doesn't need to be inserted below
CC=gcc44
CLASSES= CLArray.m CLAutoreleasePool.m CLCharacterSet.m			\
	CLMutableCharacterSet.m CLControl.m CLCookie.m CLData.m		\
	CLMutableData.m CLDictionary.m CLElement.m CLField.m CLForm.m	\
	CLImageElement.m CLImageRep.m CLMutableArray.m			\
	CLMutableDictionary.m CLNumber.m CLObject.m CLOpenFile.m	\
	CLOption.m CLPage.m CLPageObject.m CLPageStack.m CLBlock.m	\
	CLAttribute.m CLDatabase.m CLSybaseDatabase.m			\
	CLMySQLDatabase.m Header.m CLCalendarDate.m CLTimeZone.m	\
	CLAccount.m CLSession.m CLManager.m CLValidation.m		\
	CLPageTarget.m CLDecimalNumber.m CLHashTable.m			\
	CLGenericRecord.m CLInvocation.m CLMethodSignature.m		\
	CLRelationship.m CLRangeView.m CLPager.m CLNull.m		\
	CLPlaceholder.m CLNumberFormatter.m CLDateFormatter.m		\
	CLEmailMessage.m CLEmailHeader.m CLSortDescriptor.m		\
	CLChainedSelect.m CLString.m CLUTF8String.m CLConstantString.m	\
	CLConstantUnicodeString.m CLMutableString.m			\
	CLRegularExpression.m CLOriginalImage.m CLCachedImage.m		\
	CLOriginalFile.m CLCategory.m CLWikiString.m CLWikiObject.m	\
	CLWikiImage.m CLWikiLink.m CLWikiMedia.m CLStandardContent.m	\
	CLStandardContentCategory.m CLStandardContentFile.m		\
	CLStandardContentImage.m CLFileType.m CLPaymentGateway.m	\
	CLPayflowGateway.m CLAuthorizeNetGateway.m			\
	CLPaypalDirectGateway.m CLCreditCard.m CLMailingAddress.m	\
	CLAccessControl.m CLSplitter.m CLValue.m CLExpression.m		\
	CLScriptElement.m CLTCPStream.m CLEditingContext.m		\
	CLReleaseTracker.m
MFILES= CLStream.m CLDecimal.m CLDecimalMPZ.m CLStringFunctions.m	\
	CLGetArgs.m
CFILES= 
FFILES=
CFLAGS= -m32 -g -Wall -Wno-import -I$(HOME)/Unix/$(OSTYPE)/include
OCFLAGS=-fconstant-string-class=CLConstantString
MAKEFILEDIR=/usr/local/Makefiles
MAKEFILE=lib.make

-include Makefile.preamble

include $(MAKEFILEDIR)/$(MAKEFILE)

-include Makefile.postamble

-include Makefile.dependencies

.js.jh:
	sed  -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/^\(.*\)$$/@"\1\\n"/' $*.js > $*.jh

CLChainedSelect.m: CLChainedSelect.jh
