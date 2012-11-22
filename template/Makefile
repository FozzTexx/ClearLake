PRODUCT=        cl
# If PRODUCT= line is missing, be sure to insert one
# $(PRODUCT).c will be automatically compiled, so it
# doesn't need to be inserted below
CLASSES=        
CFILES=
MFILES= $(PRODUCT)_main.m
CFLAGS= -m32 -g -Wall -Wno-import -I$(HOME)/Unix/$(OSTYPE)/include \
	-fconstant-string-class=CLConstantString
MYSQL_LIBS= -L/usr/lib/mysql -L/usr/lib64/mysql -lmysqlclient
SYBASE_LIBS=-lct
OTHER_LIBS=-lClearLake -lobjc -lcrypt \
        -lpiclib -lm -ljpeg -lpng -lpthread -lgmp \
	$(MYSQL_LIBS) $(SYBASE_LIBS)
MAKEFILEDIR=/usr/local/Makefiles
MAKEFILE=single.make

-include Makefile.preamble

include $(MAKEFILEDIR)/$(MAKEFILE)

-include Makefile.postamble

-include Makefile.dependencies
