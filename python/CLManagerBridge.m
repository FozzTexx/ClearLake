#import "CLManagerBridge.h"
#import "CLPythonBridge.h"
#import "CLPythonModule.h"
#import <ClearLake/CLManager.h>

static int CLManagerBridge_init(CLPyBridgeLink *self, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"_bridgeObject", NULL};
  PyObject *bridgeCapsule = NULL;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "|O!:__init__", kwlist,
				   &PyCapsule_Type, &bridgeCapsule))
    return -1;

  if (!bridgeCapsule)
    self->bridgeObject = [[CLManager manager] retain];
  else
    self->bridgeObject = [(id) PyCapsule_GetPointer(bridgeCapsule, NULL) retain];

  return 0;
}

static void CLManagerBridge_dealloc(CLPyBridgeLink *self)
{
  [self->bridgeObject release];
  return;
}

static PyObject *CLManagerBridge_activeSession(CLPyBridgeLink *self,
					       PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([self->bridgeObject activeSession]);
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
  .tp_basicsize = sizeof(CLPyBridgeLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_base = &CLPyBridgeType,
  .tp_new = PyType_GenericNew,
  .tp_init = (initproc) CLManagerBridge_init,
  .tp_dealloc = (destructor) CLManagerBridge_dealloc,
  .tp_getset = CLManagerBridge_getsetters,
};
