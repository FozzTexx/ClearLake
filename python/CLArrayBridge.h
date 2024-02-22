#ifndef CLARRAYBRDIGE_H
#define CLARRAYBRDIGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import <ClearLake/CLArray.h>

@interface CLArray (CLPythonExtensions)
-(PyObject *) pythonObject;
@end

#endif /* CLARRAYBRDIGE_H */
