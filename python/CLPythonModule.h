#ifndef _CLPYTHONMODULE_H
#define _CLPYTHONMODULE_H

#import <ClearLake/CLRuntime.h>

@class CLString;

extern PyObject *CLPythonClassFromString(CLString *aString);
extern BOOL CLPythonIsBridgeClass(PyTypeObject *pyType);
extern PyTypeObject *CLPythonBridgeTypeForClass(Class aClass);
extern Class CLPythonBridgeSuperclassForClass(PyObject *pyClass);
extern PyObject *CLPythonObjectForObject(id anObject);

#endif /* _CLPYTHONMODULE_H */
