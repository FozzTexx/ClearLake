#import "CLPageBridge.h"
#import "CLPythonBridge.h"
#import "CLStreamBridge.h"
#import <ClearLake/CLPage.h>

static int CLPageBridge_init(CLPyBridgeLink *self, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"path", "owner", NULL};
  CLString *path = nil;
  id owner = nil;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "O&|O&", kwlist,
                                   CLPyBridgeConvert, &path,
                                   CLPyBridgeConvert, &owner))
    return -1;

  self->bridgeObject = [[CLPage alloc] initFromFile:path owner:owner];
  [self->bridgeObject setPythonObject:(PyObject *) self];

  return 0;
}

static void CLPageBridge_dealloc(CLPyBridgeLink *self)
{
  [self->bridgeObject release];
  return;
}

static PyObject *CLPageBridge_display(CLPyBridgeLink *self, PyObject *Py_UNUSED(ignored))
{
  [self->bridgeObject display];
  Py_RETURN_NONE;
}

static PyObject *CLPageBridge_updateBindings(CLPyBridgeLink *self, PyObject *Py_UNUSED(ignored))
{
  [self->bridgeObject updateBindings];
  Py_RETURN_NONE;
}

static PyObject *CLPageBridge_status(CLPyBridgeLink *self, PyObject *Py_UNUSED(ignored))
{
  return PyLong_FromLong([self->bridgeObject status]);
}

static PyObject *CLPageBridge_owner(CLPyBridgeLink *self, PyObject *Py_UNUSED(ignored))
{
  return [[self->bridgeObject owner] pythonObject];
}

static int CLPageBridge_setOwner(CLPyBridgeLink *self, PyObject *value, void *closure)
{
  [self->bridgeObject setOwner:[CLPythonBridge objectWithPythonObject:value]];
  return 0;
}

static PyObject *CLPageBridge_writeHTML(CLPyBridgeLink *self, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"htmlStream", "headerStream", NULL};
  CLStream *htmlStream = nil, *headerStream = nil;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "O&|O&", kwlist,
                                   CLPyBridgeConvertStream, &htmlStream,
                                   CLPyBridgeConvertStream, &headerStream))
    return NULL;

  [self->bridgeObject writeHTML:htmlStream headers:headerStream];
  Py_RETURN_NONE;
}

static PyObject *CLPageBridge_getItem(CLPyBridgeLink *self, PyObject *key)
{
  PyObject *value;
  id element;


  if (!PyUnicode_Check(key)) {
    PyErr_SetString(PyExc_TypeError, "key must be a string");
    return NULL;
  }

  element = [self->bridgeObject objectWithID:[CLPythonBridge objectWithPythonObject:key]];
  if (!element) {
    if (!PyErr_Occurred()) {
      PyErr_SetObject(PyExc_KeyError, key);
    }
    return NULL;
  }

  value = [element pythonObject];
  Py_INCREF(value);
  return value;
}

static PyMappingMethods CLPageBridge_mapping = {
  NULL, (binaryfunc) CLPageBridge_getItem, NULL
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
};
