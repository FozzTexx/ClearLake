#import "CLInputBridge.h"
#import "CLPythonBridge.h"
#import "CLPythonModule.h"
#import "CLStringBridge.h"
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

static PyObject *CLInputBridge_setErrorString(CLPyBridgeLink *pySelf, PyObject *args,
					      PyObject *kwds)
{
  static char *kwlist[] = {"error", "ignoreBinding", NULL};
  CLString *error;
  int ignoreBinding = NO;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "O&|p", kwlist,
                                   CLPyBridgeConvertString, &error,
				   &ignoreBinding))
    return NULL;

  [pySelf->bridgeObject setErrorString:error ignoreBinding:ignoreBinding];
  Py_RETURN_NONE;
}

static PyMethodDef CLInputBridge_methods[] = {
  {"setErrorString", (PyCFunction) CLInputBridge_setErrorString, METH_VARARGS | METH_KEYWORDS,
   "set the error string which will be shown to the user"},
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
  .tp_methods = CLInputBridge_methods,
  .tp_getset = CLInputBridge_getsetters,
};
