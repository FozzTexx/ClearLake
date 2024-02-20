#ifndef CLPAGEBRIDGE_H
#define CLPAGEBRIDGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import "CLObjectBridge.h"

extern int CLPageBridge_init(CLBridgeObject *self, PyObject *args, PyObject *kwds);
extern void CLPageBridge_dealloc(CLBridgeObject *self);
extern PyObject *CLPageBridge_display(CLBridgeObject *self, PyObject *Py_UNUSED(ignored));
extern PyTypeObject CLPageBridgeType;

#endif /* CLPAGEBRIDGETHON_H */
