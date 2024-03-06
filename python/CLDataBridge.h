#ifndef _CLDATABRIDGE_H
#define _CLDATABRIDGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import <ClearLake/CLData.h>

@interface CLData (CLPythonExtensions)
+(id) dataFromPythonObject:(PyObject *) pyBytes;
-(id) initFromPythonObject:(PyObject *) pyBytes;
@end

#endif /* _CLDATABRIDGE_H */

extern int CLPythonConvertData(PyObject *anObj, void *address);
