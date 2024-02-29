#ifndef _CLNUMBERBRIDGE_H
#define _CLNUMBERBRIDGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import <ClearLake/CLNumber.h>

@interface CLNumber (CLPythonExtensions)
-(PyObject *) pythonObject;
@end

#endif /* _CLNUMBERBRIDGE_H */
