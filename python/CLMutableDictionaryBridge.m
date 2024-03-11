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


  reserved = ((void *) self) - sizeof(CLObjectReserved);
  data = reserved->privateData;
  if (!data || !data->pyObject) {
    CLPyBridgeLink *obj;
    PyTypeObject *type;


    if (!data) {
      data = calloc(1, sizeof(CLBridgeData));
      reserved->privateData = data;
    }

    type = &CLMutableDictionaryBridgeType;
    obj = (CLPyBridgeLink *) type->tp_new(type, PyTuple_New(0), NULL);
    obj->bridgeObject = [self retain];
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

static PyObject *CLPyBridgeIterator_iternext(CLPyBridgeIterator *self)
{
  CLDictionary *aDict = self->dict;
  id aKey;
  PyObject *key, *value, *result = NULL;


  if (self->pos < [aDict count]) {
    aKey = [[aDict allKeys] objectAtIndex:self->pos];
    key = CLNativeToPython(aKey);
    value = CLNativeToPython([aDict objectForKey:aKey]);
    result = PyTuple_Pack(2, key, value);
    Py_XDECREF(key);
    Py_XDECREF(value);
    self->pos++;
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

static int CLMutableDictionaryBridge_init(CLPyBridgeLink *self, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"_bridgeObject", NULL};
  PyObject *bridgeCapsule = NULL;
  PyObject *iterable = NULL, *iterator = NULL, *item = NULL;
  Py_ssize_t pos = 0;
  PyObject *key = NULL, *value = NULL;
  int err = 0;


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
    self->bridgeObject = [[CLMutableDictionary alloc] init];
    [self->bridgeObject setPythonObject:(PyObject *) self];
  }
  else
    self->bridgeObject = [(id) PyCapsule_GetPointer(bridgeCapsule, NULL) retain];

  while (iterator && (item = PyIter_Next(iterator))) {
    if (!PyTuple_Check(item) || PyTuple_Size(item) != 2) {
      PyErr_SetString(PyExc_TypeError, "iterable must yield 2-tuples");
      err++;
      goto error;
    }

    key = PyTuple_GetItem(item, 0); // Borrowed reference
    value = PyTuple_GetItem(item, 1); // Borrowed reference
    [self->bridgeObject setObject:CLPythonToNative(value)
			   forKey:CLPythonToNative(key)];

    Py_DECREF(item);
  }

  if (PyErr_Occurred()) {
    err++;
    goto error;
  }

  if (kwds && PyDict_Check(kwds)) {
    while (PyDict_Next(kwds, &pos, &key, &value))
      [self->bridgeObject setObject:CLPythonToNative(value)
			     forKey:CLPythonToNative(key)];

    if (PyErr_Occurred()) {
      err++;
      goto error;
    }
  }

 error:
  Py_XDECREF(iterator);
  Py_XDECREF(item);

  if (err)
    [self->bridgeObject release];
  return err ? 0 : -1;
}

static void CLMutableDictionaryBridge_dealloc(CLPyBridgeLink *self)
{
  [self->bridgeObject release];
  return;
}

static PyObject *CLMutableDictionaryBridge_keys(CLPyBridgeLink *self)
{
  PyObject *pyTuple = NULL;


  CLPythonTupleFromArray([self->bridgeObject allKeys], &pyTuple);
  return pyTuple;
}

static Py_ssize_t CLMutableDictionaryBridge_length(CLPyBridgeLink *self)
{
  return [self->bridgeObject count];
}

static PyObject *CLMutableDictionaryBridge_getItem(CLPyBridgeLink *self, PyObject *key)
{
  id value;

  value = [self->bridgeObject objectForKey:CLPythonToNative(key)];
  if (!value) {
    if (!PyErr_Occurred()) {
      PyErr_SetObject(PyExc_KeyError, key);
    }
    return NULL;
  }

  return CLNativeToPython(value);
}

static int CLMutableDictionaryBridge_setItem(CLPyBridgeLink *self, PyObject *key,
					     PyObject *value)
{
  CLString *aKey;


  aKey = CLPythonToNative(key);
  if (value == NULL)
    [self->bridgeObject removeObjectForKey:aKey];
  else
    [self->bridgeObject setObject:CLPythonToNative(value) forKey:aKey];

  return 0;
}

#if 0
PyObject *CLMutableDictionaryBridge_iter(CLPyBridgeLink *self)
{
  CLPyBridgeIterator *iter = PyObject_New(CLPyBridgeIterator, &CLPyBridgeIteratorType);


  if (!iter)
    return NULL;

  Py_INCREF(self);
  iter->dict = self->bridgeObject;
  iter->pos = 0;
  return (PyObject *) iter;
}
#endif

static PyMappingMethods CLMutableDictionaryBridge_mapping = {
  (lenfunc) CLMutableDictionaryBridge_length,
  (binaryfunc) CLMutableDictionaryBridge_getItem,
  (objobjargproc) CLMutableDictionaryBridge_setItem
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
#if 0
  .tp_iter = (getiterfunc) CLMutableDictionaryBridge_iter,
#endif
};
