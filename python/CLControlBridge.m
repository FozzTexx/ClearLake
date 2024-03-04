#import "CLControlBridge.h"
#import "CLObjectBridge.h"
#import <ClearLake/CLControl.h>

static int CLControlBridge_init(CLObjectLink *self, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"string", "page", NULL};
  CLString *string = nil;
  id page = nil;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "|O&O&", kwlist,
                                   CLPythonConvert, &string,
                                   CLPythonConvert, &page))
    return -1;

  self->bridgeObject = [[CLControl alloc] initFromString:string onPage:page];

  return 0;
}

static void CLControlBridge_dealloc(CLObjectLink *self)
{
  [self->bridgeObject release];
  return;
}

static PyObject *CLControlBridge_visible(CLObjectLink *self, PyObject *Py_UNUSED(ignored))
{
  return PyBool_FromLong([self->bridgeObject isVisible]);
}

static int CLControlBridge_setVisible(CLObjectLink *self, PyObject *value, void *closure)
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
  .tp_basicsize = sizeof(CLObjectLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_base = &CLObjectBridgeType,
  .tp_new = PyType_GenericNew,
  .tp_init = (initproc) CLControlBridge_init,
  .tp_dealloc = (destructor) CLControlBridge_dealloc,
  .tp_getset = CLControlBridge_getsetters,
};
