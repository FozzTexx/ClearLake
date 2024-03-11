#ifndef _CLARRAYBRDIGE_H
#define _CLARRAYBRDIGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import <ClearLake/CLArray.h>

@interface CLArray (CLPythonExtensions)
+(id) arrayWithPythonObject:(PyObject *) pyTuple;
-(PyObject *) pythonObject;
@end

extern void CLPythonTupleFromArray(CLArray *anArray, PyObject **pyObject);
//extern PyObject *CLPythonTupleFromArray(CLArray *anArray);

#endif /* _CLARRAYBRDIGE_H */
