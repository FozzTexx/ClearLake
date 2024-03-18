#import "CLGenericRecordBridge.h"
#import "CLPythonBridge.h"
#import "CLPythonModule.h"
#import <ClearLake/CLGenericRecord.h>
#import <ClearLake/CLNumber.h>

static PyObject *CLGenericRecordBridge_getattro(CLPyBridgeLink *pySelf, PyObject *attr)
{
  id curBridge, anObject;
  BOOL found = NO;
  CLString *aKey;


  aKey = CLPythonToNative(attr);
  if ([pySelf->bridgeObject hasFieldNamed:aKey]) {
    /* Prevent going into an infinite loop of getting attributes then
       calling the native object which then tries to get
       attributes... */
    curBridge = pySelf->bridgeObject;
    pySelf->bridgeObject = nil;

    anObject = [curBridge objectValueForKey:aKey found:&found];
    pySelf->bridgeObject = curBridge;

    if (found)
      return CLNativeToPython(anObject);
  }

  return PyObject_GenericGetAttr((PyObject *) pySelf, attr);
}

static int CLGenericRecordBridge_setattro(CLPyBridgeLink *pySelf, PyObject *attr,
					  PyObject *value)
{
  id curBridge;
  BOOL found = NO;
  CLString *aKey;


  aKey = CLPythonToNative(attr);
  if ([pySelf->bridgeObject hasFieldNamed:aKey]) {
    /* Prevent going into an infinite loop of getting attributes then
       calling the native object which then tries to get
       attributes... */
    curBridge = pySelf->bridgeObject;
    pySelf->bridgeObject = nil;

    [curBridge setObjectValue:CLPythonToNative(value) forKey:aKey found:&found];
    pySelf->bridgeObject = curBridge;

    if (found)
      return 0;
  }

  return PyObject_GenericSetAttr((PyObject *) pySelf, attr, value);
}

static PyObject *CLGenericRecordBridge_hasFlag(CLPyBridgeLink *pySelf, PyObject *args,
					       PyObject *kwds)
{
  static char *kwlist[] = {"flag", NULL};
  int flag;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "C", kwlist, &flag))
    return NULL;

  return PyBool_FromLong([pySelf->bridgeObject hasFlag:flag]);
}

static PyObject *CLGenericRecordBridge_addFlag(CLPyBridgeLink *pySelf, PyObject *args,
					       PyObject *kwds)
{
  static char *kwlist[] = {"flag", NULL};
  int flag;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "C", kwlist, &flag))
    return NULL;

  [pySelf->bridgeObject addFlag:flag];
  Py_RETURN_NONE;
}

static PyObject *CLGenericRecordBridge_removeFlag(CLPyBridgeLink *pySelf, PyObject *args,
					 PyObject *kwds)
{
  static char *kwlist[] = {"flag", NULL};
  int flag;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "C", kwlist, &flag))
    return NULL;

  [pySelf->bridgeObject removeFlag:flag];
  Py_RETURN_NONE;
}

static PyMethodDef CLGenericRecordBridge_methods[] = {
  {"hasFlag", (PyCFunction) CLGenericRecordBridge_hasFlag, METH_VARARGS | METH_KEYWORDS,
    "return True if specified character flag is set"},
  {"addFlag", (PyCFunction) CLGenericRecordBridge_addFlag, METH_VARARGS | METH_KEYWORDS,
    "set the specified character flag"},
  {"removeFlag", (PyCFunction) CLGenericRecordBridge_removeFlag, METH_VARARGS | METH_KEYWORDS,
    "unset the specified character flag"},
  {NULL},
};

PyTypeObject CLGenericRecordBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLGenericRecord",
  .tp_doc = PyDoc_STR("ClearLake object representing an genericrecord"),
  .tp_basicsize = sizeof(CLPyBridgeLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_base = &CLPyBridgeType,
  .tp_new = PyType_GenericNew,
  .tp_methods = CLGenericRecordBridge_methods,
  .tp_getattro = (getattrofunc) CLGenericRecordBridge_getattro,
  .tp_setattro = (setattrofunc) CLGenericRecordBridge_setattro,
};
