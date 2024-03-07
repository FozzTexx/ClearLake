#ifndef _CLSTRINGBRIDGE_H
#define _CLSTRINGBRIDGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import <ClearLake/CLString.h>

@interface CLString (CLPythonExtensions)
+(id) stringFromPythonObject:(PyObject *) pyString;
-(id) initFromPythonObject:(PyObject *) pyString;
@end

extern int CLPyBridgeConvertString(PyObject *anObj, void *address);

#endif /* _CLSTRINGBRIDGE_H */
