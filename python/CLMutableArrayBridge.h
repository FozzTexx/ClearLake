#ifndef _CLMUTABLEARRAYBRIDGE_H
#define _CLMUTABLEARRAYBRIDGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import <ClearLake/CLMutableArray.h>

@interface CLMutableArray (CLPythonExtensions)
+(id) arrayWithPythonObject:(PyObject *) pyList;
-(PyObject *) pythonObject;
@end

@interface CLMutableArrayBridge:CLMutableArray <CLArraySubclass, CLMutableArraySubclass>
-(id) initWithPythonObject:(PyObject *) pyObject;
-(void) dealloc;
@end

#endif /* _CLMUTABLEARRAYBRIDGE_H */
