#ifndef _CLDATABRIDGE_H
#define _CLDATABRIDGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import <ClearLake/CLData.h>

@interface CLData (CLPythonExtensions)
-(PyObject *) pythonObject;
@end

#endif /* _CLDATABRIDGE_H */
