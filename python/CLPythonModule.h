#ifndef _CLPYTHONMODULE_H
#define _CLPYTHONMODULE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import <ClearLake/CLRuntime.h>

@class CLString, CLPythonBridge;

extern PyTypeObject *CLPythonClassFromString(CLString *aString);
extern PyTypeObject *CLPythonBridgeTypeForClass(Class aClass);
extern BOOL CLIsBridgeClass(PyTypeObject *pyType);
extern BOOL CLInheritsFromBridgeClass(PyTypeObject *pyType);
extern Class CLNativeSuperclassForPythonClass(PyObject *pyClass);
extern Class CLClassForPythonClass(PyTypeObject *pyClass);
extern Class CLClassForPythonObject(PyObject *pyObject);

#if 0
extern PyObject *CLNativeToPython(id anObject);
extern id CLPythonToNative(PyObject *pyObject);
#else
#define CLNativeToPython(x) ({ \
      id _x = x; \
      _x ? [_x pythonObject] : Py_NewRef(Py_None);	\
    })
#define CLPythonToNative(x) ({ \
      PyObject *_x = x; \
      [CLPythonBridge objectWithPythonObject:_x]; \
    })
#endif

#endif /* _CLPYTHONMODULE_H */
