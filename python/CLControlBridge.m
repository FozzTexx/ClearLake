#import "CLControlBridge.h"
#import "CLElementBridge.h"
#import "CLPythonModule.h"
#import "CLPythonBridge.h"
#import "CLStringBridge.h"
#import <ClearLake/CLControl.h>
#import <ClearLake/CLPage.h>

static PyObject *CLControlBridge_navigateTo(CLPyBridgeLink *pySelf, PyObject *args,
					    PyObject *kwds)
{
  static char *kwlist[] = {"owner", "selector", NULL};
  id owner;
  CLString *selector;
  BOOL success;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "O&O&", kwlist,
                                   CLPyBridgeConvert, &owner,
                                   CLPyBridgeConvertString, &selector))
    return NULL;

  if ([selector characterAtIndex:[selector length] - 1] != ':')
    selector = [selector stringByAppendingString:@":"];
  if (!owner) {
    [pySelf->bridgeObject setPage:nil];
    CLRedirectBrowserToPage(selector, NO);
    success = YES;
  }
  else {
    success = [owner replacePage:pySelf->bridgeObject selector:CLSelectorFromString(selector)];
    if (!success)
      success = [owner replacePage:pySelf->bridgeObject
			  filename:[selector substringToIndex:[selector length] - 1]];
  }

  return PyLong_FromLong(success);
}

static PyMethodDef CLControlBridge_methods[] = {
  {
    "navigateTo", (PyCFunction) CLControlBridge_navigateTo, METH_VARARGS | METH_KEYWORDS,
    "replace the control's page with the selector using owner as the page owner",
  },
  {NULL},
};

static PyObject *CLControlBridge_visible(CLPyBridgeLink *pySelf, PyObject *Py_UNUSED(ignored))
{
  return PyBool_FromLong([pySelf->bridgeObject isVisible]);
}

static int CLControlBridge_setVisible(CLPyBridgeLink *pySelf, PyObject *value, void *closure)
{
  [pySelf->bridgeObject setVisible:PyObject_IsTrue(value)];
  return 0;
}

static PyObject *CLControlBridge_target(CLPyBridgeLink *pySelf, PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([pySelf->bridgeObject target]);
}

static int CLControlBridge_setTarget(CLPyBridgeLink *pySelf, PyObject *value, void *closure)
{
  [pySelf->bridgeObject setTarget:CLPythonToNative(value)];
  return 0;
}

static PyGetSetDef CLControlBridge_getsetters[] = {
  {"visible", (getter) CLControlBridge_visible, (setter) CLControlBridge_setVisible,
   "boolean represinting if element is visible", "set if the element is visible"},
  {"target", (getter) CLControlBridge_target, (setter) CLControlBridge_setTarget,
   "object that will be called to do action", "set object to receive action"},
  {NULL},
};

PyTypeObject CLControlBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLControl",
  .tp_doc = PyDoc_STR("ClearLake object representing a control"),
  .tp_basicsize = sizeof(CLPyBridgeLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_base = &CLElementBridgeType,
  .tp_new = PyType_GenericNew,
  .tp_getset = CLControlBridge_getsetters,
  .tp_methods = CLControlBridge_methods,
};
