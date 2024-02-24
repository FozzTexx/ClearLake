#ifndef CLMUTABLEARRAYBRIDGE_H
#define CLMUTABLEARRAYBRIDGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import <ClearLake/CLMutableArray.h>

@interface CLMutableArray (CLPythonExtensions)
+(id) arrayWithPythonObject:(PyObject *) pyList;
@end

@interface CLMutableArrayBridge:CLMutableArray <CLArraySubclass, CLMutableArraySubclass>
-(id) initWithPythonObject:(PyObject *) pyObject;
-(void) dealloc;
@end

#endif /* CLMUTABLEARRAYBRIDGE_H */
