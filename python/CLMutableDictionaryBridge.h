#ifndef CLMUTABLEDICTIONARYBRIDGE_H
#define CLMUTABLEDICTIONARYBRIDGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import <ClearLake/CLMutableDictionary.h>

@interface CLMutableDictionary (CLPythonExtensions)
+(id) dictionaryWithPythonObject:(PyObject *) pyList;
@end
     
@interface CLMutableDictionaryBridge:CLMutableDictionary <CLDictionarySubclass,
							    CLMutableDictionarySubclass>
-(id) initWithPythonObject:(PyObject *) pyObject;
-(void) dealloc;
@end

#endif /* CLMUTABLEDICTIONARYBRIDGE_H */
