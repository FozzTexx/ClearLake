#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import "CLMutableArrayBridge.h"
#import "CLPythonModule.h"
#import "CLPythonBridge.h"
#import "CLArrayBridge.h"

#import <ClearLake/CLConstantString.h>

@implementation CLMutableArray (CLPythonExtensions)

+(id) arrayWithPythonObject:(PyObject *) pyList
{
  return [[[CLMutableArrayBridge alloc] initWithPythonObject:pyList] autorelease];
}

-(PyObject *) pythonObject
{
  CLObjectReserved *reserved;
  CLBridgeData *data;
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif


  reserved = ((void *) self) - sizeof(CLObjectReserved);
  data = reserved->privateData;
  if (!data || !data->pyObject) {
    CLPyBridgeLink *obj;
    PyTypeObject *pyClass;
    PyObject *args;
    PyObject *kwargs = NULL;


    if (!data) {
      data = calloc(1, sizeof(CLBridgeData));
      reserved->privateData = data;
    }

    pyClass = &CLMutableArrayBridgeType;
    args = PyTuple_New(0);
    kwargs = PyDict_New();
    PyDict_SetItemString(kwargs, "_bridgeObject", PyCapsule_New(self, NULL, NULL));
    obj = (CLPyBridgeLink *) PyObject_Call((PyObject *) pyClass, args, kwargs);
    if (!obj) {
      PyErr_Print();
      [self error:@"Failed to create bridge"];
    }

    Py_XDECREF(args);
    Py_XDECREF(kwargs);

    [self setPythonObject:(PyObject *) obj];
    // setPythonObject: incremented the new reference we created
    Py_DECREF(obj);
  }

  Py_INCREF(data->pyObject);
  return data->pyObject;
}

@end

@implementation CLMutableArrayBridge

-(id) initWithPythonObject:(PyObject *) pyObject
{
  if (!PyList_Check(pyObject))
    [self error:@"object is not a Python list"];
  [super init];
  Py_INCREF(pyObject);
  arrayData = pyObject;
  return self;
}

-(void) dealloc
{
  Py_DECREF(arrayData);
  [super dealloc];
  return;
}

-(CLUInteger) count
{
  return PyList_Size(arrayData);
}

-(id) objectAtIndex:(CLUInteger) index
{
  return CLPythonToNative(PyList_GetItem(arrayData, index));
}

-(void) write:(CLStream *) stream
{
  CLArray *anArray = [[CLArray alloc] initWithArray:self];


  [anArray write:stream];
  [anArray release];
  return;
}

@end

static int CLMutableArrayBridge_init(CLPyBridgeLink *pySelf, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"iterable", "_bridgeObject", NULL};
  PyObject *bridgeCapsule = NULL;
  PyObject *iterable = NULL, *iterator = NULL, *item = NULL;
  int err = 0;
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "|OO!:__init__", kwlist,
				   &iterable,
				   &PyCapsule_Type, &bridgeCapsule))
    return -1;

  if (iterable) {
    iterator = PyObject_GetIter(iterable);
    if (iterator == NULL) {
      PyErr_SetString(PyExc_TypeError, "argument must be iterable");
      return -1;
    }
  }

  if (!bridgeCapsule) {
    pySelf->bridgeObject = [[CLMutableArray alloc] init];
    [pySelf->bridgeObject setPythonObject:(PyObject *) pySelf];
  }
  else
    pySelf->bridgeObject = [(id) PyCapsule_GetPointer(bridgeCapsule, NULL) retain];

  while (iterator && (item = PyIter_Next(iterator))) {
    [pySelf->bridgeObject addObject:CLPythonToNative(item)];
    Py_DECREF(item);
  }

  if (PyErr_Occurred()) {
    err++;
    goto error;
  }

 error:
  Py_XDECREF(iterator);
  Py_XDECREF(item);

  if (err)
    [pySelf->bridgeObject release];
  return err ? -1 : 0;
}

static void CLMutableArrayBridge_dealloc(CLPyBridgeLink *pySelf)
{
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif
  [pySelf->bridgeObject release];
  return;
}

static Py_ssize_t CLMutableArrayBridge_length(CLPyBridgeLink *pySelf)
{
  return [pySelf->bridgeObject count];
}

static PyObject *CLMutableArrayBridge_getItem(CLPyBridgeLink *pySelf, Py_ssize_t idx)
{
  id value;


  if (idx < 0 || idx >= [pySelf->bridgeObject count]) {
    PyErr_SetString(PyExc_IndexError, "index out of range");
    return NULL;
  }

  value = [pySelf->bridgeObject objectAtIndex:idx];
  return CLNativeToPython(value);
}

static int CLMutableArrayBridge_setItem(CLPyBridgeLink *pySelf, Py_ssize_t idx,
					PyObject *value)
{
  if (idx < 0 || idx >= [pySelf->bridgeObject count]) {
    PyErr_SetString(PyExc_IndexError, "index out of range");
    return -1;
  }

  if (value)
    [pySelf->bridgeObject insertObject:CLPythonToNative(value) atIndex:idx+1];
  [pySelf->bridgeObject removeObjectAtIndex:idx];
  return 0;
}

static PySequenceMethods CLMutableArrayBridge_sequence = {
  .sq_length = (lenfunc) CLMutableArrayBridge_length,
  .sq_item = (ssizeargfunc) CLMutableArrayBridge_getItem,
  .sq_ass_item = (ssizeobjargproc) CLMutableArrayBridge_setItem,
};

PyTypeObject CLMutableArrayBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLMutableArray",
  .tp_doc = PyDoc_STR("ClearLake object representing a array"),
  .tp_basicsize = sizeof(CLPyBridgeLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_base = &CLPyBridgeType,
  .tp_new = PyType_GenericNew,
  .tp_init = (initproc) CLMutableArrayBridge_init,
  .tp_dealloc = (destructor) CLMutableArrayBridge_dealloc,
  .tp_as_sequence = &CLMutableArrayBridge_sequence,
};
