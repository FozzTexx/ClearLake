#ifndef _CLPYTHONBRIDGE_H
#define _CLPYTHONBRIDGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

typedef struct {
  PyObject_HEAD
  id bridgeObject;
} CLPyBridgeLink;

#import <ClearLake/CLObject.h>

typedef struct {
  void *originalPrivate;
  PyObject *pyObject;
} CLBridgeData;

@interface CLPythonBridge:CLObject
+(Class) createBridgeClass:(CLString *) name;
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
