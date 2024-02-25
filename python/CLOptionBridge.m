#import "CLOptionBridge.h"
#import "CLObjectBridge.h"
#import "CLStringBridge.h"
#import <ClearLake/CLOption.h>

int CLOptionBridge_init(CLObjectLink *self, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"label", "value", "selected", NULL};
  CLString *label = nil;
  id value = nil;
  int selected = NO;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "O&O&|p", kwlist,
                                   CLPythonConvertString, &label,
                                   CLPythonConvert, &value,
                                   &selected))
    return -1;

  self->bridgeObject = [[CLOption alloc] initWithString:label andValue:value
                                               selected:selected];

  return 0;
}

void CLOptionBridge_dealloc(CLObjectLink *self)
{
  [self->bridgeObject release];
  return;
}

PyTypeObject CLOptionBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLOption",
  .tp_doc = PyDoc_STR("ClearLake object representing a select option"),
  .tp_basicsize = sizeof(CLObjectLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_new = PyType_GenericNew,
  .tp_init = (initproc) CLOptionBridge_init,
  .tp_dealloc = (destructor) CLOptionBridge_dealloc,
};
