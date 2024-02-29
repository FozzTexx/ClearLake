#ifndef _CLOBJECTBRIDGE_H
#define _CLOBJECTBRIDGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import <ClearLake/CLObject.h>

@interface CLObjectBridge:CLObject <CLArchiving>
{
  PyObject *bridged;
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

#endif /* _CLOBJECTBRIDGE_H */
