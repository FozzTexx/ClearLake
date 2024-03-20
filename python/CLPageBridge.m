#import "CLPageBridge.h"
#import "CLPythonBridge.h"
#import "CLStreamBridge.h"
#import "CLPythonModule.h"
#import <ClearLake/CLPage.h>

static int CLPageBridge_init(CLPyBridgeLink *pySelf, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"path", "owner", "_bridgeObject"};
  PyObject *bridgeCapsule = NULL;
  CLString *path = nil;
  id owner = nil;
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "|O&O&O!:__init__", kwlist,
                                   CLPyBridgeConvert, &path,
                                   CLPyBridgeConvert, &owner,
				   &PyCapsule_Type, &bridgeCapsule))
    return -1;

  if (!bridgeCapsule) {
    pySelf->bridgeObject = [[CLPage alloc] initFromFile:path owner:owner];
    [pySelf->bridgeObject setPythonObject:(PyObject *) pySelf];
  }
  else
    pySelf->bridgeObject = [(id) PyCapsule_GetPointer(bridgeCapsule, NULL) retain];

  return 0;
}

static void CLPageBridge_dealloc(CLPyBridgeLink *pySelf)
{
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif
  [pySelf->bridgeObject release];
  return;
}

static PyObject *CLPageBridge_display(CLPyBridgeLink *pySelf, PyObject *Py_UNUSED(ignored))
{
  [pySelf->bridgeObject display];
  Py_RETURN_NONE;
}

static PyObject *CLPageBridge_updateBindings(CLPyBridgeLink *pySelf, PyObject *Py_UNUSED(ignored))
{
  [pySelf->bridgeObject updateBindings];
  Py_RETURN_NONE;
}

static PyObject *CLPageBridge_status(CLPyBridgeLink *pySelf, PyObject *Py_UNUSED(ignored))
{
  return PyLong_FromLong([pySelf->bridgeObject status]);
}

static PyObject *CLPageBridge_owner(CLPyBridgeLink *pySelf, PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([pySelf->bridgeObject owner]);
}

static int CLPageBridge_setOwner(CLPyBridgeLink *pySelf, PyObject *value, void *closure)
{
  [pySelf->bridgeObject setOwner:CLPythonToNative(value)];
  return 0;
}

static PyObject *CLPageBridge_writeHTML(CLPyBridgeLink *pySelf, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"htmlStream", "headerStream", NULL};
  CLStream *htmlStream = nil, *headerStream = nil;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "O&|O&", kwlist,
                                   CLPyBridgeConvertStream, &htmlStream,
                                   CLPyBridgeConvertStream, &headerStream))
    return NULL;

  [pySelf->bridgeObject writeHTML:htmlStream headers:headerStream];
  Py_RETURN_NONE;
}

static PyObject *CLPageBridge_getItem(CLPyBridgeLink *pySelf, PyObject *key)
{
  id element;


  if (!PyUnicode_Check(key)) {
    PyErr_SetString(PyExc_TypeError, "key must be a string");
    return NULL;
  }

  element = [pySelf->bridgeObject objectWithID:CLPythonToNative(key)];
  if (!element) {
    if (!PyErr_Occurred()) {
      PyErr_SetObject(PyExc_KeyError, key);
    }
    return NULL;
  }

  return CLNativeToPython(element);
}

static int CLPageBridge_contains(CLPyBridgeLink *pySelf, PyObject *key)
{
  if (!PyUnicode_Check(key)) {
    PyErr_SetString(PyExc_TypeError, "key must be a string");
    return -1;
  }

  return !![pySelf->bridgeObject objectWithID:CLPythonToNative(key)];
}

static PyMappingMethods CLPageBridge_mapping = {
  NULL, (binaryfunc) CLPageBridge_getItem, NULL
};

static PySequenceMethods CLPageBridge_sequence = {
  .sq_contains = (objobjproc) CLPageBridge_contains,
};

static PyMethodDef CLPageBridge_methods[] = {
  {"display", (PyCFunction) CLPageBridge_display, METH_NOARGS,
    "render the page and send it to stdout"},
  {"updateBindings", (PyCFunction) CLPageBridge_updateBindings, METH_NOARGS,
    "update all the dynamic content on the page"},
  {"writeHTML", (PyCFunction) CLPageBridge_writeHTML, METH_VARARGS | METH_KEYWORDS,
    "write out the HTML and optionally the headers"},
  {NULL},
};

static PyGetSetDef CLPageBridge_getsetters[] = {
  {"status", (getter) CLPageBridge_status, NULL, "HTTP status of the page", NULL},
  {"owner", (getter) CLPageBridge_owner, (setter) CLPageBridge_setOwner,
   "get the page owner", "set the page owner"},
  {NULL},
};

PyTypeObject CLPageBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLPage",
  .tp_doc = PyDoc_STR("ClearLake object representing a web page"),
  .tp_basicsize = sizeof(CLPyBridgeLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_base = &CLPyBridgeType,
  .tp_new = PyType_GenericNew,
  .tp_init = (initproc) CLPageBridge_init,
  .tp_dealloc = (destructor) CLPageBridge_dealloc,
  .tp_methods = CLPageBridge_methods,
  .tp_getset = CLPageBridge_getsetters,
  .tp_as_mapping = &CLPageBridge_mapping,
  .tp_as_sequence = &CLPageBridge_sequence,
};
