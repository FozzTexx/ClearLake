#import "CLInputBridge.h"
#import "CLPythonBridge.h"
#import "CLPythonModule.h"
#import <ClearLake/CLInput.h>

static PyObject *CLInputBridge_value(CLPyBridgeLink *pySelf, PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([pySelf->bridgeObject value]);
}

static int CLInputBridge_setValue(CLPyBridgeLink *pySelf, PyObject *value, void *closure)
{
  [pySelf->bridgeObject setValue:CLPythonToNative(value)];
  return 0;
}

static PyGetSetDef CLInputBridge_getsetters[] = {
  {"value", (getter) CLInputBridge_value, (setter) CLInputBridge_setValue,
   "get the value", "set the value"},
  {NULL},
};

PyTypeObject CLInputBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLInput",
  .tp_doc = PyDoc_STR("ClearLake object representing an input or field"),
  .tp_basicsize = sizeof(CLPyBridgeLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_base = &CLPyBridgeType,
  .tp_new = PyType_GenericNew,
  .tp_getset = CLInputBridge_getsetters,
};
