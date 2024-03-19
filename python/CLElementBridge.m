#import "CLElementBridge.h"
#import "CLPythonModule.h"
#import "CLPythonBridge.h"
#import "CLStringBridge.h"
#import <ClearLake/CLElement.h>
#import <ClearLake/CLPage.h>

static int CLElementBridge_init(CLPyBridgeLink *pySelf, PyObject *args, PyObject *kwds)
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
    pySelf->bridgeObject = [[CLElement alloc] initFromString:string onPage:page];
    [pySelf->bridgeObject setPythonObject:(PyObject *) pySelf];
  }
  else
    pySelf->bridgeObject = [(id) PyCapsule_GetPointer(bridgeCapsule, NULL) retain];

  return 0;
}

static void CLElementBridge_dealloc(CLPyBridgeLink *pySelf)
{
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif
  [pySelf->bridgeObject release];
  return;
}

static PyObject *CLElementBridge_attributes(CLPyBridgeLink *pySelf,
					    PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([pySelf->bridgeObject attributes]);
}

static PyGetSetDef CLElementBridge_getsetters[] = {
  {"attributes", (getter) CLElementBridge_attributes, NULL,
   "attributes of the element", NULL},
  {NULL},
};

PyTypeObject CLElementBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLElement",
  .tp_doc = PyDoc_STR("ClearLake object representing a element"),
  .tp_basicsize = sizeof(CLPyBridgeLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_base = &CLPyBridgeType,
  .tp_new = PyType_GenericNew,
  .tp_init = (initproc) CLElementBridge_init,
  .tp_dealloc = (destructor) CLElementBridge_dealloc,
  .tp_getset = CLElementBridge_getsetters,
};
