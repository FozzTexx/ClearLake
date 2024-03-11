#import "CLFormBridge.h"
#import "CLControlBridge.h"
#import "CLPythonBridge.h"
#import "CLPageBridge.h"
#import "CLPythonModule.h"
#import <ClearLake/CLPage.h>
#import <ClearLake/CLForm.h>
#import <ClearLake/CLInput.h>

static int CLFormBridge_init(CLPyBridgeLink *self, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"string", "page", "_bridgeObject", NULL};
  PyObject *bridgeCapsule = NULL;
  CLString *string = nil;
  id page = nil;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "|O&O&O!:__init__", kwlist,
                                   CLPyBridgeConvert, &string,
                                   CLPyBridgeConvert, &page,
				   &PyCapsule_Type, &bridgeCapsule))
    return -1;

  if (!bridgeCapsule) {
    self->bridgeObject = [[CLForm alloc] initFromString:string onPage:page];
    [self->bridgeObject setPythonObject:(PyObject *) self];
  }
  else
    self->bridgeObject = [(id) PyCapsule_GetPointer(bridgeCapsule, NULL) retain];

  return 0;
}

static void CLFormBridge_dealloc(CLPyBridgeLink *self)
{
  [self->bridgeObject release];
  return;
}

static PyObject *CLFormBridge_page(CLPyBridgeLink *self, PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([self->bridgeObject page]);
}

#if 0
static PyObject *CLFormBridge_valueOfFieldNamed(CLPyBridgeLink *self,
                                                PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"name", NULL};
  CLString *name = nil;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "O&", kwlist,
                                   CLPyBridgeConvert, &name))
    return NULL;

  return CLNativeToPython([self->bridgeObject valueOfFieldNamed:name]);
}
#endif

static PyObject *CLFormBridge_getItem(CLPyBridgeLink *self, PyObject *key)
{
  id field;


  if (!PyUnicode_Check(key)) {
    PyErr_SetString(PyExc_TypeError, "key must be a string");
    return NULL;
  }

  field = [self->bridgeObject fieldNamed:CLPythonToNative(key)];
  if (!field) {
    if (!PyErr_Occurred()) {
      PyErr_SetObject(PyExc_KeyError, key);
    }
    return NULL;
  }

  return CLNativeToPython([field value]);
}

static int CLFormBridge_setItem(CLPyBridgeLink *self, PyObject *key, PyObject *value)
{
  CLString *aField;


  if (!PyUnicode_Check(key)) {
    PyErr_SetString(PyExc_TypeError, "key must be a string");
    return -1;
  }

  aField = CLPythonToNative(key);
  if (value == NULL)
    [self->bridgeObject setValue:nil forFieldNamed:aField];
  else
    [self->bridgeObject setValue:CLPythonToNative(value) forFieldNamed:aField];

  return 0;
}

static PyMappingMethods CLFormBridge_mapping = {
  NULL, (binaryfunc) CLFormBridge_getItem, (objobjargproc) CLFormBridge_setItem
};

static PyGetSetDef CLFormBridge_getsetters[] = {
  {"page", (getter) CLFormBridge_page, NULL, "page that the form is on", NULL},
  {NULL},
};

#if 0
PyMethodDef CLFormBridge_methods[] = {
  {
    "valueOfFieldNamed", (PyCFunction) CLFormBridge_valueOfFieldNamed,
    METH_VARARGS | METH_KEYWORDS,
    "returns the value of the field with ID matching name",
  },
  {NULL},
};
#endif

PyTypeObject CLFormBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLForm",
  .tp_doc = PyDoc_STR("ClearLake object representing a form"),
  .tp_basicsize = sizeof(CLPyBridgeLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_base = &CLControlBridgeType,
  .tp_new = PyType_GenericNew,
  .tp_init = (initproc) CLFormBridge_init,
  .tp_dealloc = (destructor) CLFormBridge_dealloc,
#if 0
  .tp_methods = CLFormBridge_methods,
#endif
  .tp_getset = CLFormBridge_getsetters,
  .tp_as_mapping = &CLFormBridge_mapping,
};
