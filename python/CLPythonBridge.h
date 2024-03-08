#ifndef _CLPYTHONBRIDGE_H
#define _CLPYTHONBRIDGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import <ClearLake/CLObject.h>

typedef struct {
  PyObject_HEAD
  id bridgeObject;
} CLPyBridgeLink;

typedef struct {
  void *originalPrivate;
  PyObject *pyObject;
} CLBridgeData;

@interface CLPythonBridge:CLObject
+(Class) createBridgeClassFromPythonClass:(PyTypeObject *) pyClass;
+(id) objectWithPythonObject:(PyObject *) pyObject;

-(id) initWithPythonObject:(PyObject *) pyObject;
-(void) dealloc;
@end

@interface CLObject (CLPythonBridgeExtensions)
-(PyObject *) pythonObject;
-(void) setPythonObject:(PyObject *) pyObject;
@end

extern int CLPyBridgeConvert(PyObject *anObj, void *address);

extern PyTypeObject CLPyBridgeType;

#endif /* _CLPYTHONBRIDGE_H */
