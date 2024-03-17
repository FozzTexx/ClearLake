#import "CLFormBridge.h"
#import "CLControlBridge.h"
#import "CLPythonBridge.h"
#import "CLPageBridge.h"
#import "CLPythonModule.h"
#import "CLStringBridge.h"
#import <ClearLake/CLPage.h>
#import <ClearLake/CLForm.h>
#import <ClearLake/CLInput.h>

static int CLFormBridge_init(CLPyBridgeLink *pySelf, PyObject *args, PyObject *kwds)
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
    pySelf->bridgeObject = [[CLForm alloc] initFromString:string onPage:page];
    [pySelf->bridgeObject setPythonObject:(PyObject *) pySelf];
  }
  else
    pySelf->bridgeObject = [(id) PyCapsule_GetPointer(bridgeCapsule, NULL) retain];

  return 0;
}

static void CLFormBridge_dealloc(CLPyBridgeLink *pySelf)
{
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif
  [pySelf->bridgeObject release];
  return;
}

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
  id field;


  if (!PyUnicode_Check(key)) {
    PyErr_SetString(PyExc_TypeError, "key must be a string");
    return NULL;
  }

  if ((field = [pySelf->bridgeObject fieldNamed:CLPythonToNative(key)]))
    return CLNativeToPython([field value]);

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

static PyObject *CLFormBridge_contains(CLPyBridgeLink *pySelf, PyObject *key)
{
  if (!PyUnicode_Check(key)) {
    PyErr_SetString(PyExc_TypeError, "key must be a string");
    return NULL;
  }

  return PyBool_FromLong([pySelf->bridgeObject fieldNamed:CLPythonToNative(key)]);
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
  {
    "fieldsNamed", (PyCFunction) CLFormBridge_fieldsNamed, METH_VARARGS | METH_KEYWORDS,
    "returns all the fields with ID matching name",
  },
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
  .tp_init = (initproc) CLFormBridge_init,
  .tp_dealloc = (destructor) CLFormBridge_dealloc,
  .tp_methods = CLFormBridge_methods,
  .tp_getset = CLFormBridge_getsetters,
  .tp_as_mapping = &CLFormBridge_mapping,
  .tp_as_sequence = &CLFormBridge_sequence,
};
