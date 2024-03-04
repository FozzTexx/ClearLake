#import "CLManagerBridge.h"
#import "CLObjectBridge.h"
#import "CLPythonModule.h"
#import <ClearLake/CLManager.h>

static int CLManagerBridge_init(CLObjectLink *self, PyObject *args, PyObject *kwds)
{
  if (!PyArg_ParseTuple(args, ":__init__"))
    return -1;

  self->bridgeObject = [[CLManager manager] retain];

  return 0;
}

static void CLManagerBridge_dealloc(CLObjectLink *self)
{
  [self->bridgeObject release];
  return;
}

static PyObject *CLManagerBridge_activeSession(CLObjectLink *self,
					       PyObject *Py_UNUSED(ignored))
{
  return CLPythonObjectForObject([self->bridgeObject activeSession]);
}

static PyGetSetDef CLManagerBridge_getsetters[] = {
  {"activeSession", (getter) CLManagerBridge_activeSession, NULL,
   "active ClearLake session", NULL},
  {NULL},
};

PyTypeObject CLManagerBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLManager",
  .tp_doc = PyDoc_STR("ClearLake object representing a web manager"),
  .tp_basicsize = sizeof(CLObjectLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_base = &CLObjectBridgeType,
  .tp_new = PyType_GenericNew,
  .tp_init = (initproc) CLManagerBridge_init,
  .tp_dealloc = (destructor) CLManagerBridge_dealloc,
  .tp_getset = CLManagerBridge_getsetters,
};
