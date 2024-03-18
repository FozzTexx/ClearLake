#import "CLManagerBridge.h"
#import "CLPythonBridge.h"
#import "CLPythonModule.h"
#import <ClearLake/CLManager.h>

static int CLManagerBridge_init(CLPyBridgeLink *pySelf, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"_bridgeObject", NULL};
  PyObject *bridgeCapsule = NULL;
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "|O!:__init__", kwlist,
				   &PyCapsule_Type, &bridgeCapsule))
    return -1;

  if (!bridgeCapsule)
    pySelf->bridgeObject = [[CLManager manager] retain];
  else
    pySelf->bridgeObject = [(id) PyCapsule_GetPointer(bridgeCapsule, NULL) retain];

  return 0;
}

static void CLManagerBridge_dealloc(CLPyBridgeLink *pySelf)
{
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif
  [pySelf->bridgeObject release];
  return;
}

static PyObject *CLManagerBridge_login(CLPyBridgeLink *pySelf, PyObject *sender)
{
  [pySelf->bridgeObject login:CLPythonToNative(sender)];
  Py_RETURN_NONE;
}

static PyObject *CLManagerBridge_activeSession(CLPyBridgeLink *pySelf,
					       PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([pySelf->bridgeObject activeSession]);
}

static PyGetSetDef CLManagerBridge_getsetters[] = {
  {"activeSession", (getter) CLManagerBridge_activeSession, NULL,
   "active ClearLake session", NULL},
  {NULL},
};

static PyMethodDef CLManagerBridge_methods[] = {
  {"login", (PyCFunction) CLManagerBridge_login, METH_O,
    "try to login with the credentials provided in sender"},
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
  .tp_methods = CLManagerBridge_methods,
  .tp_getset = CLManagerBridge_getsetters,
};
