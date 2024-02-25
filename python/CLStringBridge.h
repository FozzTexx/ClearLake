#ifndef CLSTRINGBRIDGE_H
#define CLSTRINGBRIDGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import <ClearLake/CLString.h>

@interface CLString (CLPythonExtensions)
+(id) stringFromPythonObject:(PyObject *) pyString;
-(id) initFromPythonObject:(PyObject *) pyString;
-(PyObject *) pythonObject;
@end

extern int CLPythonConvertString(PyObject *anObj, void *address);

#endif /* CLSTRINGBRIDGETHON_H */
