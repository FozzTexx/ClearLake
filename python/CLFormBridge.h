#ifndef CLFORMBRIDGE_H
#define CLFORMBRIDGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import "CLObjectBridge.h"

extern int CLFormBridge_init(CLObjectLink *self, PyObject *args, PyObject *kwds);
extern void CLFormBridge_dealloc(CLObjectLink *self);
extern PyTypeObject CLFormBridgeType;

#endif /* CLFORMBRIDGE_H */
