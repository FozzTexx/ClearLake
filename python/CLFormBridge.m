#import "CLFormBridge.h"
#import "CLControlBridge.h"
#import "CLPythonBridge.h"
#import "CLPageBridge.h"
#import "CLPythonModule.h"
#import "CLStringBridge.h"
#import <ClearLake/CLPage.h>
#import <ClearLake/CLForm.h>
#import <ClearLake/CLInput.h>

static PyObject *CLFormBridge_page(CLPyBridgeLink *pySelf, PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([pySelf->bridgeObject page]);
}

static PyObject *CLFormBridge_fieldsNamed(CLPyBridgeLink *pySelf, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"name", NULL};
  CLString *name = nil;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "O&", kwlist,
                                   CLPyBridgeConvertString, &name))
    return NULL;

  return CLNativeToPython([pySelf->bridgeObject fieldsNamed:name]);
}

static PyObject *CLFormBridge_getItem(CLPyBridgeLink *pySelf, PyObject *key)
{
  CLInput *aField;


  if (!PyUnicode_Check(key)) {
    PyErr_SetString(PyExc_TypeError, "key must be a string");
    return NULL;
  }

  if ((aField = [pySelf->bridgeObject fieldNamed:CLPythonToNative(key)]))
    return CLNativeToPython([aField value]);

  PyErr_SetObject(PyExc_KeyError, key);
  return NULL;
}

static int CLFormBridge_setItem(CLPyBridgeLink *pySelf, PyObject *key, PyObject *value)
{
  CLString *aField;


  if (!PyUnicode_Check(key)) {
    PyErr_SetString(PyExc_TypeError, "key must be a string");
    return -1;
  }

  aField = CLPythonToNative(key);
  if (value == NULL)
    [pySelf->bridgeObject setValue:nil forFieldNamed:aField];
  else
    [pySelf->bridgeObject setValue:CLPythonToNative(value) forFieldNamed:aField];

  return 0;
}

static int CLFormBridge_contains(CLPyBridgeLink *pySelf, PyObject *key)
{
  if (!PyUnicode_Check(key)) {
    PyErr_SetString(PyExc_TypeError, "key must be a string");
    return -1;
  }

  return !![pySelf->bridgeObject fieldNamed:CLPythonToNative(key)];
}

static PyObject *CLFormBridge_get(CLPyBridgeLink *pySelf, PyObject *args)
{
  PyObject *key, *defaultVal = Py_None;
  CLInput *aField;


  if (!PyArg_ParseTuple(args, "U|O", &key, &defaultVal))
    return NULL;

  if ((aField = [pySelf->bridgeObject fieldNamed:CLPythonToNative(key)]))
    return CLNativeToPython([aField value]);

  Py_INCREF(defaultVal);
  return defaultVal;
}

static PyObject *CLFormBridge_copyValuesFrom(CLPyBridgeLink *pySelf, PyObject *form)
{
  [pySelf->bridgeObject copyValuesFrom:CLPythonToNative(form)];
  Py_RETURN_NONE;
}

static PyMappingMethods CLFormBridge_mapping = {
  .mp_length = NULL,
  .mp_subscript = (binaryfunc) CLFormBridge_getItem,
  .mp_ass_subscript = (objobjargproc) CLFormBridge_setItem,
};

static PySequenceMethods CLFormBridge_sequence = {
  .sq_contains = (objobjproc) CLFormBridge_contains,
};

static PyGetSetDef CLFormBridge_getsetters[] = {
  {"page", (getter) CLFormBridge_page, NULL, "page that the form is on", NULL},
  {NULL},
};

PyMethodDef CLFormBridge_methods[] = {
  {"fieldsNamed", (PyCFunction) CLFormBridge_fieldsNamed, METH_VARARGS | METH_KEYWORDS,
    "returns all the fields with ID matching name"},
  {"get", (PyCFunction) CLFormBridge_get, METH_VARARGS,
   "gets the contents of the named field, else default"},
  {"copyValuesFrom", (PyCFunction) CLFormBridge_copyValuesFrom, METH_O,
   "copy values into fields from the passed form or dict"},
  {NULL},
};

PyTypeObject CLFormBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLForm",
  .tp_doc = PyDoc_STR("ClearLake object representing a form"),
  .tp_basicsize = sizeof(CLPyBridgeLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_base = &CLControlBridgeType,
  .tp_new = PyType_GenericNew,
  .tp_methods = CLFormBridge_methods,
  .tp_getset = CLFormBridge_getsetters,
  .tp_as_mapping = &CLFormBridge_mapping,
  .tp_as_sequence = &CLFormBridge_sequence,
};
