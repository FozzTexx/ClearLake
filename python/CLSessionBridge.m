#import "CLSessionBridge.h"
#import "CLPythonBridge.h"
#import "CLPythonModule.h"

static PyObject *CLSessionBridge_account(CLPyBridgeLink *self, PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([self->bridgeObject account]);
}

static int CLSessionBridge_setAccount(CLPyBridgeLink *self, PyObject *value, void *closure)
{
  [self->bridgeObject setAccount:CLPythonToNative(value)];
  return 0;
}

static PyGetSetDef CLSessionBridge_getsetters[] = {
  {"account", (getter) CLSessionBridge_account, (setter) CLSessionBridge_setAccount,
   "get the account", "set the account"},
  {NULL},
};

PyTypeObject CLSessionBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLSession",
  .tp_doc = PyDoc_STR("ClearLake object representing a session"),
  .tp_basicsize = sizeof(CLPyBridgeLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_base = &CLPyBridgeType,
  .tp_new = PyType_GenericNew,
  .tp_getset = CLSessionBridge_getsetters,
};
