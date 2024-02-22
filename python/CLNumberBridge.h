#ifndef CLNUMBERBRIDGE_H
#define CLNUMBERBRIDGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import <ClearLake/CLNumber.h>

@interface CLNumber (CLPythonExtensions)
-(PyObject *) pythonObject;
@end

#endif /* CLNUMBERBRIDGE_H */
