#import "CLPageBridge.h"
#import "CLObjectBridge.h"
#import "CLStreamBridge.h"

@implementation CLPage (CLPythonExtensions)

-(PyObject *) pythonObject
{
  CLObjectLink *obj;


  obj = (CLObjectLink *) CLPageBridgeType.tp_new(&CLPageBridgeType, PyTuple_New(0), NULL);
  obj->bridgeObject = [self retain];
  return (PyObject *) obj;
}

@end

static int CLPageBridge_init(CLObjectLink *self, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"path", "owner", NULL};
  CLString *path = nil;
  id owner = nil;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "O&|O&", kwlist,
				   CLPythonConvert, &path,
				   CLPythonConvert, &owner))
    return -1;

  self->bridgeObject = [[CLPage alloc] initFromFile:path owner:owner];

  return 0;
}

static void CLPageBridge_dealloc(CLObjectLink *self)
{
  [self->bridgeObject release];
  return;
}

static PyObject *CLPageBridge_display(CLObjectLink *self, PyObject *Py_UNUSED(ignored))
{
  [self->bridgeObject display];
  Py_RETURN_NONE;
}

static PyObject *CLPageBridge_updateBindings(CLObjectLink *self, PyObject *Py_UNUSED(ignored))
{
  [self->bridgeObject updateBindings];
  Py_RETURN_NONE;
}

static PyObject *CLPageBridge_status(CLObjectLink *self, PyObject *Py_UNUSED(ignored))
{
  return PyLong_FromLong([self->bridgeObject status]);
}

static PyObject *CLPageBridge_owner(CLObjectLink *self, PyObject *Py_UNUSED(ignored))
{
  return [[self->bridgeObject owner] pythonObject];
}

static int CLPageBridge_setOwner(CLObjectLink *self, PyObject *value, void *closure)
{
  [self->bridgeObject setOwner:[CLObjectBridge objectWithPythonObject:value]];
  return 0;
}

static PyObject *CLPageBridge_writeHTML(CLObjectLink *self, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"htmlStream", "headerStream", NULL};
  CLStream *htmlStream = nil, *headerStream = nil;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "O&|O&", kwlist,
				   CLPythonConvertStream, &htmlStream,
				   CLPythonConvertStream, &headerStream))
    return NULL;

  [self->bridgeObject writeHTML:htmlStream headers:headerStream];
  Py_RETURN_NONE;
}

static PyObject *CLPageBridge_getItem(CLObjectLink *self, PyObject *key)
{
  PyObject *value;
  id element;


  if (!PyUnicode_Check(key)) {
    PyErr_SetString(PyExc_TypeError, "key must be a string");
    return NULL;
  }

  element = [self->bridgeObject objectWithID:[CLObjectBridge objectWithPythonObject:key]];
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
  {
    "display", (PyCFunction) CLPageBridge_display, METH_NOARGS,
    "render the page and send it to stdout",
  },
  {
    "updateBindings", (PyCFunction) CLPageBridge_updateBindings, METH_NOARGS,
    "update all the dynamic content on the page",
  },  
  {
    "writeHTML", (PyCFunction) CLPageBridge_writeHTML, METH_VARARGS | METH_KEYWORDS,
    "write out the HTML and optionally the headers",
  },
  {NULL},
};

static PyGetSetDef CLPageBridge_getsetters[] = {
  {"status", (getter) CLPageBridge_status, NULL, "HTTP status of the page", NULL},
  {"owner", (getter) CLPageBridge_owner, CLPageBridge_setOwner,
   "get the page owner", "set the page owner"},
  {NULL},
};

PyTypeObject CLPageBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLPage",
  .tp_doc = PyDoc_STR("ClearLake object representing a web page"),
  .tp_basicsize = sizeof(CLObjectLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_new = PyType_GenericNew,
  .tp_init = (initproc) CLPageBridge_init,
  .tp_dealloc = (destructor) CLPageBridge_dealloc,
  .tp_methods = CLPageBridge_methods,
  .tp_getset = CLPageBridge_getsetters,
  .tp_as_mapping = &CLPageBridge_mapping,
};
