#import "CLPageBridge.h"
#import "CLObjectBridge.h"
#import "CLStreamBridge.h"
#import <ClearLake/CLPage.h>

int CLPageBridge_init(CLBridgeObject *self, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"path", "owner", NULL};
  CLString *path = nil;
  id owner = nil;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "O&|O&", kwlist,
				   CLObjectBridgeConvert, &path,
				   CLObjectBridgeConvert, &owner))
    return -1;

  self->bridgeObject = [[CLPage alloc] initFromFile:path owner:owner];

  return 0;
}

void CLPageBridge_dealloc(CLBridgeObject *self)
{
  [self->bridgeObject release];
  return;
}

PyObject *CLPageBridge_display(CLBridgeObject *self, PyObject *Py_UNUSED(ignored))
{
  [self->bridgeObject display];
  Py_INCREF(Py_None);
  return Py_None;
}

PyObject *CLPageBridge_updateBindings(CLBridgeObject *self, PyObject *Py_UNUSED(ignored))
{
  [self->bridgeObject updateBindings];
  Py_INCREF(Py_None);
  return Py_None;
}

PyObject *CLPageBridge_status(CLBridgeObject *self, PyObject *Py_UNUSED(ignored))
{
  return PyLong_FromLong([self->bridgeObject status]);
}

PyObject *CLPageBridge_writeHTML(CLBridgeObject *self, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"stream", "withHeaders", NULL};
  CLStream *stream = nil;
  int withHeaders = 1;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "O&|p", kwlist,
				   CLPythonStreamConvert, &stream,
				   &withHeaders))
    return NULL;

  [self->bridgeObject writeHTML:stream withHeaders:withHeaders];
  Py_INCREF(Py_None);
  return Py_None;
}

PyMethodDef CLPageBridge_methods[] = {
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
  {NULL},
};

PyTypeObject CLPageBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLPage",
  .tp_doc = PyDoc_STR("ClearLake object representing a web page"),
  .tp_basicsize = sizeof(CLBridgeObject),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_new = PyType_GenericNew,
  .tp_init = (initproc) CLPageBridge_init,
  .tp_dealloc = (destructor) CLPageBridge_dealloc,
  .tp_methods = CLPageBridge_methods,
  .tp_getset = CLPageBridge_getsetters,
};

