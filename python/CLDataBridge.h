#ifndef CLDATABRIDGE_H
#define CLDATABRIDGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import <ClearLake/CLData.h>

@interface CLData (CLPythonExtensions)
-(PyObject *) pythonObject;
@end

#endif /* CLDATABRIDGE_H */
