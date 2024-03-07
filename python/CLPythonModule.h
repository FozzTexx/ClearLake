#ifndef _CLPYTHONMODULE_H
#define _CLPYTHONMODULE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import <ClearLake/CLRuntime.h>

@class CLString;

extern PyObject *CLPythonClassFromString(CLString *aString);
extern BOOL CLIsBridgeClass(PyTypeObject *pyType);
extern PyTypeObject *CLPythonBridgeTypeForClass(Class aClass);
extern Class CLNativeSuperclassForPythonClass(PyObject *pyClass);
extern Class CLClassForPythonObject(PyObject *pyObject);
extern PyObject *CLPythonObjectForNativeObject(id anObject);

#endif /* _CLPYTHONMODULE_H */
