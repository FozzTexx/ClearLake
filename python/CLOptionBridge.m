#import "CLOptionBridge.h"
#import "CLPythonBridge.h"
#import "CLStringBridge.h"
#import <ClearLake/CLOption.h>

int CLOptionBridge_init(CLPyBridgeLink *pySelf, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"label", "value", "selected", "_bridgeObject", NULL};
  PyObject *bridgeCapsule = NULL;
  CLString *label = nil;
  id value = nil;
  int selected = NO;
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "O&O&|pO!:__init__", kwlist,
                                   CLPyBridgeConvertString, &label,
                                   CLPyBridgeConvert, &value,
                                   &selected,
				   &PyCapsule_Type, &bridgeCapsule))
    return -1;

  if (!bridgeCapsule) {
    pySelf->bridgeObject = [[CLOption alloc] initWithString:label andValue:value
						 selected:selected];
    [pySelf->bridgeObject setPythonObject:(PyObject *) pySelf];
  }
  else
    pySelf->bridgeObject = [(id) PyCapsule_GetPointer(bridgeCapsule, NULL) retain];

  return 0;
}

void CLOptionBridge_dealloc(CLPyBridgeLink *pySelf)
{
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif
  [pySelf->bridgeObject release];
  return;
}

PyTypeObject CLOptionBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLOption",
  .tp_doc = PyDoc_STR("ClearLake object representing a select option"),
  .tp_basicsize = sizeof(CLPyBridgeLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_base = &CLPyBridgeType,
  .tp_new = PyType_GenericNew,
  .tp_init = (initproc) CLOptionBridge_init,
  .tp_dealloc = (destructor) CLOptionBridge_dealloc,
};
