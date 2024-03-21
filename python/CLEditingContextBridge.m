#import "CLEditingContextBridge.h"
#import "CLPythonModule.h"
#import "CLPythonBridge.h"
#import "CLStringBridge.h"
#import <ClearLake/CLEditingContext.h>

static PyObject *CLEditingContextBridge_loadTableWithClass(CLPyBridgeLink *pySelf,
							   PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"class", "qualifier", "orderBy", NULL};
  PyObject *pyClass;
  CLString *qualifier = nil, *orderBy = nil;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "O|O&O&", kwlist,
                                   &pyClass,
                                   CLPyBridgeConvertString, &qualifier,
				   CLPyBridgeConvertString, &orderBy))
    return NULL;

  return CLNativeToPython([pySelf->bridgeObject
			      loadTableWithClass:
				   CLClassForPythonClass((PyTypeObject *) pyClass)
			      qualifier:qualifier orderBy:orderBy]);
}

static PyObject *CLEditingContextBridge_database(PyObject *cls,
						 PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([CLEditingContext database]);
}

static PyMethodDef CLEditingContextBridge_methods[] = {
  {"loadTableWithClass", (PyCFunction) CLEditingContextBridge_loadTableWithClass,
   METH_VARARGS | METH_KEYWORDS,
   "load table which represents class using qualifier and optionally sorting by orderBy"},
  {"database", (PyCFunction) CLEditingContextBridge_database, METH_NOARGS | METH_CLASS,
    "get the main database object"},
  {NULL},
};

PyTypeObject CLEditingContextBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLEditingContext",
  .tp_doc = PyDoc_STR("ClearLake object representing a database editing context"),
  .tp_basicsize = sizeof(CLPyBridgeLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_base = &CLPyBridgeType,
  .tp_new = PyType_GenericNew,
  .tp_methods = CLEditingContextBridge_methods,
};
