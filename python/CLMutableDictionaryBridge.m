#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import "CLMutableDictionaryBridge.h"
#import "CLPythonModule.h"
#import "CLPythonBridge.h"
#import "CLArrayBridge.h"
#import <ClearLake/CLString.h>

@implementation CLMutableDictionary (CLPythonExtensions)

+(id) dictionaryWithPythonObject:(PyObject *) pyList
{
  return [[[CLMutableDictionaryBridge alloc] initWithPythonObject:pyList] autorelease];
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

    pyClass = &CLMutableDictionaryBridgeType;
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

@implementation CLMutableDictionaryBridge

-(id) initWithPythonObject:(PyObject *) pyObject
{
  [super init];
  Py_INCREF(pyObject);
  dictionaryData = pyObject;
  return self;
}

-(void) dealloc
{
  Py_DECREF(dictionaryData);
  [super dealloc];
  return;
}

-(CLUInteger) count
{
  return PyDict_Size(dictionaryData);
}

-(id) objectForKey:(id) aKey
{
  return CLPythonToNative(PyDict_GetItemString(dictionaryData,
					       [[aKey description] UTF8String]));
}

-(CLArray *) allKeys
{
  PyObject *pyKeys;
  id keys;


  pyKeys = PyDict_Keys(dictionaryData);
  keys = CLPythonToNative(pyKeys);
  Py_DECREF(pyKeys);
  return keys;
}

-(CLArray *) allValues
{
  PyObject *pyValues;
  id values;


  pyValues = PyDict_Values(dictionaryData);
  values = CLPythonToNative(pyValues);
  Py_DECREF(pyValues);
  return values;
}

-(CLString *) className
{
  return [CLMutableDictionary className];
}

-(void) write:(CLStream *) stream
{
  CLDictionary *aDict = [[CLDictionary alloc] initFromDictionary:self];


  [aDict write:stream];
  [aDict release];
  return;
}

@end

#if 0
typedef struct {
  PyObject_HEAD
  id dict;
  Py_ssize_t pos;
} CLPyBridgeIterator;

static PyObject *CLPyBridgeIterator_iternext(CLPyBridgeIterator *pySelf)
{
  CLDictionary *aDict = pySelf->dict;
  id aKey;
  PyObject *key, *value, *result = NULL;


  if (pySelf->pos < [aDict count]) {
    aKey = [[aDict allKeys] objectAtIndex:pySelf->pos];
    key = CLNativeToPython(aKey);
    value = CLNativeToPython([aDict objectForKey:aKey]);
    result = PyTuple_Pack(2, key, value);
    Py_XDECREF(key);
    Py_XDECREF(value);
    pySelf->pos++;
  }
  else
    PyErr_SetNone(PyExc_StopIteration);

  return result;
}

PyTypeObject CLPyBridgeIteratorType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLPyBridgeIterator",
  .tp_basicsize = sizeof(CLPyBridgeIterator),
  .tp_iternext = (iternextfunc) CLPyBridgeIterator_iternext,
};
#endif

static int CLMutableDictionaryBridge_init(CLPyBridgeLink *pySelf, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"iterable", "_bridgeObject", NULL};
  PyObject *bridgeCapsule = NULL;
  PyObject *iterable = NULL, *iterator = NULL, *item = NULL;
  Py_ssize_t pos = 0;
  PyObject *key = NULL, *value = NULL;
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
    pySelf->bridgeObject = [[CLMutableDictionary alloc] init];
    [pySelf->bridgeObject setPythonObject:(PyObject *) pySelf];
  }
  else
    pySelf->bridgeObject = [(id) PyCapsule_GetPointer(bridgeCapsule, NULL) retain];

  while (iterator && (item = PyIter_Next(iterator))) {
    if (!PyTuple_Check(item) || PyTuple_Size(item) != 2) {
      PyErr_SetString(PyExc_TypeError, "iterable must yield 2-tuples");
      err++;
      goto error;
    }

    key = PyTuple_GetItem(item, 0); // Borrowed reference
    value = PyTuple_GetItem(item, 1); // Borrowed reference
    [pySelf->bridgeObject setObject:CLPythonToNative(value)
			   forKey:CLPythonToNative(key)];

    Py_DECREF(item);
  }

  if (PyErr_Occurred()) {
    err++;
    goto error;
  }

  if (kwds && PyDict_Check(kwds)) {
    while (PyDict_Next(kwds, &pos, &key, &value)) {
      if (!PyCapsule_CheckExact(value))
	[pySelf->bridgeObject setObject:CLPythonToNative(value)
				 forKey:CLPythonToNative(key)];
    }

    if (PyErr_Occurred()) {
      err++;
      goto error;
    }
  }

 error:
  Py_XDECREF(iterator);
  Py_XDECREF(item);

  if (err)
    [pySelf->bridgeObject release];
  return err ? -1 : 0;
}

static void CLMutableDictionaryBridge_dealloc(CLPyBridgeLink *pySelf)
{
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif
  [pySelf->bridgeObject release];
  return;
}

static PyObject *CLMutableDictionaryBridge_keys(CLPyBridgeLink *pySelf)
{
  PyObject *pyTuple = NULL;


  CLPythonTupleFromArray([pySelf->bridgeObject allKeys], &pyTuple);
  return pyTuple;
}

static Py_ssize_t CLMutableDictionaryBridge_length(CLPyBridgeLink *pySelf)
{
  return [pySelf->bridgeObject count];
}

static PyObject *CLMutableDictionaryBridge_getItem(CLPyBridgeLink *pySelf, PyObject *key)
{
  id value;


  if ((value = [pySelf->bridgeObject objectForKey:CLPythonToNative(key)]))
    return CLNativeToPython(value);

  PyErr_SetObject(PyExc_KeyError, key);
  return NULL;
}

static int CLMutableDictionaryBridge_setItem(CLPyBridgeLink *pySelf, PyObject *key,
					     PyObject *value)
{
  CLString *aKey;


  aKey = CLPythonToNative(key);
  if (value == NULL)
    [pySelf->bridgeObject removeObjectForKey:aKey];
  else
    [pySelf->bridgeObject setObject:CLPythonToNative(value) forKey:aKey];

  return 0;
}

static PyObject *CLMutableDictionaryBridge_contains(CLPyBridgeLink *pySelf, PyObject *key)
{
  if (!PyUnicode_Check(key)) {
    PyErr_SetString(PyExc_TypeError, "key must be a string");
    return NULL;
  }

  return PyBool_FromLong([pySelf->bridgeObject objectForKey:CLPythonToNative(key)]);
}

#if 0
PyObject *CLMutableDictionaryBridge_iter(CLPyBridgeLink *pySelf)
{
  CLPyBridgeIterator *iter = PyObject_New(CLPyBridgeIterator, &CLPyBridgeIteratorType);


  if (!iter)
    return NULL;

  Py_INCREF(pySelf);
  iter->dict = pySelf->bridgeObject;
  iter->pos = 0;
  return (PyObject *) iter;
}
#endif

static PyMappingMethods CLMutableDictionaryBridge_mapping = {
  (lenfunc) CLMutableDictionaryBridge_length,
  (binaryfunc) CLMutableDictionaryBridge_getItem,
  (objobjargproc) CLMutableDictionaryBridge_setItem
};

static PySequenceMethods CLMutableDictionaryBridge_sequence = {
  .sq_contains = (objobjproc) CLMutableDictionaryBridge_contains,
};

static PyMethodDef CLMutableDictionaryBridge_methods[] = {
  {"keys", (PyCFunction) CLMutableDictionaryBridge_keys, METH_NOARGS,
   "return a list of all keys"},
  {NULL},
};

PyTypeObject CLMutableDictionaryBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLMutableDictionary",
  .tp_doc = PyDoc_STR("ClearLake object representing a dictionary"),
  .tp_basicsize = sizeof(CLPyBridgeLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_base = &CLPyBridgeType,
  .tp_new = PyType_GenericNew,
  .tp_init = (initproc) CLMutableDictionaryBridge_init,
  .tp_dealloc = (destructor) CLMutableDictionaryBridge_dealloc,
  .tp_methods = CLMutableDictionaryBridge_methods,
  .tp_as_mapping = &CLMutableDictionaryBridge_mapping,
  .tp_as_sequence = &CLMutableDictionaryBridge_sequence,
#if 0
  .tp_iter = (getiterfunc) CLMutableDictionaryBridge_iter,
#endif
};
