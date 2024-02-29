#ifndef _CLARRAYBRDIGE_H
#define _CLARRAYBRDIGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import <ClearLake/CLArray.h>

@interface CLArray (CLPythonExtensions)
-(PyObject *) pythonObject;
@end

#endif /* _CLARRAYBRDIGE_H */
