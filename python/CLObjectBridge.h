#ifndef CLOBJECTBRIDGE_H
#define CLOBJECTBRIDGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import <ClearLake/CLObject.h>

@interface CLObjectBridge:CLObject <CLArchiving>
{
  PyObject *pythonObject;
}

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

#endif /* CLOBJECTBRIDGE_H */
