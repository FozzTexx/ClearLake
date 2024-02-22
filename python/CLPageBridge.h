#ifndef CLPAGEBRIDGE_H
#define CLPAGEBRIDGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import "CLObjectBridge.h"

extern int CLPageBridge_init(CLObjectLink *self, PyObject *args, PyObject *kwds);
extern void CLPageBridge_dealloc(CLObjectLink *self);
extern PyObject *CLPageBridge_display(CLObjectLink *self, PyObject *Py_UNUSED(ignored));
extern PyTypeObject CLPageBridgeType;

#endif /* CLPAGEBRIDGETHON_H */
