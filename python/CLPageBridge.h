#ifndef CLPAGEBRIDGE_H
#define CLPAGEBRIDGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import "CLObjectBridge.h"
#import <ClearLake/CLPage.h>

@interface CLPage (CLPythonExtensions)
-(PyObject *) pythonObject;
@end

extern PyTypeObject CLPageBridgeType;

#endif /* CLPAGEBRIDGETHON_H */
