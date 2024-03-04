#ifndef _CLOBJECTBRIDGE_H
#define _CLOBJECTBRIDGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import <ClearLake/CLObject.h>

typedef struct {
  void *originalPrivate;
  Class original;
  PyObject *pyObject;
  CLString *pythonClassName;
} CLBridgeData;

@interface CLObject (CLPythonExtensions)
-(PyObject *) pythonObject;
@end

@interface CLObjectBridge:CLObject <CLArchiving>
+(id) objectWithPythonObject:(PyObject *) pyObject;
-(id) initWithPythonObject:(PyObject *) pyObject;
-(void) dealloc;

-(void) forwardInvocation:(CLInvocation *) anInvocation;
@end

extern int CLPythonConvert(PyObject *anObj, void *address);

typedef struct {
  PyObject_HEAD
  id bridgeObject;
} CLObjectLink;

extern PyTypeObject CLObjectBridgeType;

#endif /* _CLOBJECTBRIDGE_H */
