#ifndef _CLMUTABLEDICTIONARYBRIDGE_H
#define _CLMUTABLEDICTIONARYBRIDGE_H

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

#if 0
extern PyTypeObject CLPyBridgeIteratorType;
#endif
extern PyTypeObject CLMutableDictionaryBridgeType;

#endif /* _CLMUTABLEDICTIONARYBRIDGE_H */
