#ifndef CLOPTIONBRIDGE_H
#define CLOPTIONBRIDGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import "CLObjectBridge.h"

extern int CLOptionBridge_init(CLBridgeObject *self, PyObject *args, PyObject *kwds);
extern void CLOptionBridge_dealloc(CLBridgeObject *self);
extern PyTypeObject CLOptionBridgeType;

#endif /* CLOPTIONBRIDGE_H */
