#import "CLControlBridge.h"
#import "CLPythonBridge.h"
#import "CLStringBridge.h"
#import <ClearLake/CLControl.h>
#import <ClearLake/CLPage.h>

static int CLControlBridge_init(CLPyBridgeLink *pySelf, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"string", "page", "_bridgeObject", NULL};
  PyObject *bridgeCapsule = NULL;
  CLString *string = nil;
  id page = nil;
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "|O&O&O!:__init__", kwlist,
                                   CLPyBridgeConvert, &string,
                                   CLPyBridgeConvert, &page,
				   &PyCapsule_Type, &bridgeCapsule))
    return -1;

  if (!bridgeCapsule) {
    pySelf->bridgeObject = [[CLControl alloc] initFromString:string onPage:page];
    [pySelf->bridgeObject setPythonObject:(PyObject *) pySelf];
  }
  else
    pySelf->bridgeObject = [(id) PyCapsule_GetPointer(bridgeCapsule, NULL) retain];

  return 0;
}

static void CLControlBridge_dealloc(CLPyBridgeLink *pySelf)
{
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif
  [pySelf->bridgeObject release];
  return;
}

static PyObject *CLControl_navigateTo(CLPyBridgeLink *pySelf, PyObject *args, PyObject *kwds)
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
  else
    success = [owner replacePage:pySelf->bridgeObject selector:CLSelectorFromString(selector)];

  return PyLong_FromLong(success);
}

static PyMethodDef CLControlBridge_methods[] = {
  {
    "navigateTo", (PyCFunction) CLControl_navigateTo, METH_VARARGS | METH_KEYWORDS,
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

static PyGetSetDef CLControlBridge_getsetters[] = {
  {"visible", (getter) CLControlBridge_visible, (setter) CLControlBridge_setVisible,
   "boolean represinting if element is visible", "set if the element is visible"},
  {NULL},
};

PyTypeObject CLControlBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLControl",
  .tp_doc = PyDoc_STR("ClearLake object representing a control"),
  .tp_basicsize = sizeof(CLPyBridgeLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_base = &CLPyBridgeType,
  .tp_new = PyType_GenericNew,
  .tp_init = (initproc) CLControlBridge_init,
  .tp_dealloc = (destructor) CLControlBridge_dealloc,
  .tp_getset = CLControlBridge_getsetters,
  .tp_methods = CLControlBridge_methods,
};
