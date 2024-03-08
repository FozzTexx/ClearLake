#import "CLControlBridge.h"
#import "CLPythonBridge.h"
#import "CLStringBridge.h"
#import <ClearLake/CLControl.h>

static int CLControlBridge_init(CLPyBridgeLink *self, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"string", "page", NULL};
  CLString *string = nil;
  id page = nil;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "|O&O&", kwlist,
                                   CLPyBridgeConvert, &string,
                                   CLPyBridgeConvert, &page))
    return -1;

  self->bridgeObject = [[CLControl alloc] initFromString:string onPage:page];
  [self->bridgeObject setPythonObject:(PyObject *) self];

  return 0;
}

static void CLControlBridge_dealloc(CLPyBridgeLink *self)
{
  [self->bridgeObject release];
  return;
}

static PyObject *CLControl_navigateTo(CLPyBridgeLink *self, PyObject *args, PyObject *kwds)
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
  success = [owner replacePage:self->bridgeObject selector:sel_getUid([selector UTF8String])];

  return PyLong_FromLong(success);
}

static PyMethodDef CLControlBridge_methods[] = {
  {
    "navigateTo", (PyCFunction) CLControl_navigateTo, METH_VARARGS | METH_KEYWORDS,
    "replace the control's page with the selector using owner as the page owner",
  },
  {NULL},
};

static PyObject *CLControlBridge_visible(CLPyBridgeLink *self, PyObject *Py_UNUSED(ignored))
{
  return PyBool_FromLong([self->bridgeObject isVisible]);
}

static int CLControlBridge_setVisible(CLPyBridgeLink *self, PyObject *value, void *closure)
{
  [self->bridgeObject setVisible:PyObject_IsTrue(value)];
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
