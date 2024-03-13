#import "CLPythonModule.h"
#import "CLPythonBridge.h"
#import "CLManagerBridge.h"
#import "CLPageBridge.h"
#import "CLFormBridge.h"
#import "CLOptionBridge.h"
#import "CLArrayBridge.h"
#import "CLStreamBridge.h"
#import "CLControlBridge.h"
#import "CLOriginalFileBridge.h"
#import "CLSessionBridge.h"
#import "CLMutableDictionaryBridge.h"
#import "CLAccountBridge.h"
#import "CLInputBridge.h"

#import <ClearLake/CLAutoreleasePool.h>
#import <ClearLake/CLDictionary.h>
#import <ClearLake/CLString.h>
#import <ClearLake/CLStream.h>
#import <ClearLake/CLManager.h>
#import <ClearLake/CLNumber.h>
#import <ClearLake/CLRuntime.h>
#import <ClearLake/CLEditingContext.h>

#include <stdlib.h>

#define BRIDGE_TYPE(x) {#x, (PyTypeObject *) &x##BridgeType}

static struct {
  char *name;
  PyTypeObject *type;
} CLBridgeTypes[] = {
  {"CLPythonBridge", &CLPyBridgeType},
#if 0
  {"CLPyBridgeIterator", &CLPyBridgeIteratorType},
#endif
  BRIDGE_TYPE(CLManager),
  BRIDGE_TYPE(CLPage),
  BRIDGE_TYPE(CLForm),
  BRIDGE_TYPE(CLOption),
  BRIDGE_TYPE(CLControl),
  BRIDGE_TYPE(CLOriginalFile),
  BRIDGE_TYPE(CLSession),
  BRIDGE_TYPE(CLMutableDictionary),
  BRIDGE_TYPE(CLAccount),
  BRIDGE_TYPE(CLInput),
  {NULL, NULL},
};

static CLHashTable *_classMapping = NULL;
static CLHashTable *_nameMapping = NULL;
static int _creatingClass = 0;

Class CLPyBridgeClassFromName(const char *name)
{
  Class aClass = nil;
  PyObject *pyClass;


  /* objc_allocateClassPair will call objc_getClass which will call us
     again, avoid infinite recursion */
  if (!_creatingClass) {
    pyClass = (PyObject *) CLPythonClassFromString([CLString stringWithUTF8String:name]);
    if (pyClass) {
      _creatingClass++;
      aClass = CLClassForPythonClass((PyTypeObject *) pyClass);
      _creatingClass--;
    }
  }

  return aClass;
}

typedef struct {
  CLAutoreleasePool *pool;
} ClearLake_python_state;

#undef DICT_DEBUG
#ifdef DICT_DEBUG
static void print_dict_keys(PyObject* dict)
{
  if (!PyDict_Check(dict)) {
    fprintf(stderr, "Object is not a dictionary\n");
    return;
  }

  PyObject *keys = PyDict_Keys(dict); // Get a list of all keys in the dict
  if (keys == NULL) {
    fprintf(stderr, "Failed to get keys from dictionary\n");
    return;
  }

  Py_ssize_t i, size = PyList_Size(keys);
  for (i = 0; i < size; i++) {
    PyObject *key = PyList_GetItem(keys, i); // Borrowed reference, no need to DECREF
    PyObject *str = PyObject_Str(key); // Convert the key to a string
    if (str != NULL) {
      printf("%s\n", PyUnicode_AsUTF8(str));
      Py_DECREF(str);
    }
  }

  Py_DECREF(keys);
}
#endif

PyTypeObject *CLPythonClassFromString(CLString *aString)
{
  CLString *moduleName, *className;
  PyObject *pyModule, *pyModuleDict;
  PyTypeObject *pyClass;
  CLRange aRange;


  pyClass = CLHashTableDataForIdenticalKey(_nameMapping, aString, [aString hash]);
  if (!pyClass) {
    aRange = [aString rangeOfString:@"."];
    if (!aRange.length) {
      moduleName = @"__main__";
      className = aString;
    }
    else {
      moduleName = [aString substringToIndex:aRange.location];
      className = [aString substringFromIndex:CLMaxRange(aRange)];
    }

    pyModule = PyImport_AddModule([moduleName UTF8String]);
    pyModuleDict = PyModule_GetDict(pyModule);

#ifdef DICT_DEBUG
    printf("Searching for %s.%s\n", [moduleName UTF8String], [className UTF8String]);
    print_dict_keys(pyModuleDict);
#endif

    pyClass = PyDict_GetItemString(pyModuleDict, [className UTF8String]);
    if (pyClass && !PyType_Check(pyClass)) {
      fprintf(stderr, "Not a Python class\n");
      abort();
    }
  }

  return pyClass;
}

PyTypeObject *CLPythonBridgeTypeForClass(Class aClass)
{
  CLUInteger idx;
  const char *className = [[aClass className] UTF8String];


  for (idx = 0; CLBridgeTypes[idx].name; idx++) {
    if (!strcmp(CLBridgeTypes[idx].name, className))
      return CLBridgeTypes[idx].type;
  }

  return NULL;
}

BOOL CLIsBridgeClass(PyTypeObject *pyType)
{
  CLUInteger idx;


  while (pyType) {
    for (idx = 0; CLBridgeTypes[idx].name; idx++) {
      if (CLBridgeTypes[idx].type == pyType)
	return YES;
    }
    pyType = pyType->tp_base;
  }

  return NO;
}

Class CLNativeSuperclassForPythonClass(PyObject *pyClass)
{
  CLUInteger idx;
  PyTypeObject *type = (PyTypeObject *) pyClass;


  if (!PyType_Check(type))
    type = Py_TYPE(type);

  while (type) {
    for (idx = 0; CLBridgeTypes[idx].name; idx++) {
      if (CLBridgeTypes[idx].type == type)
	return CLClassFromString([CLString stringWithUTF8String:CLBridgeTypes[idx].name]);
    }
    type = type->tp_base;
  }

  return nil;
}

Class CLClassForPythonClass(PyTypeObject *pyClass)
{
  Class aClass;
  CLString *className;


  if (!PyType_Check(pyClass)) {
    fprintf(stderr, "Not a Python class\n");
    abort();
  }

  aClass = CLHashTableDataForIdenticalKey(_classMapping, (id) pyClass, (size_t) pyClass);
  if (!aClass) {
    _creatingClass++;
    aClass = [CLPythonBridge createBridgeClassFromPythonClass:pyClass];
    _creatingClass--;
    if (!aClass) {
      fprintf(stderr, "Failed to create class");
      abort();
    }
    CLHashTableSetData(_classMapping, aClass, (id) pyClass, (size_t) pyClass);
    className = [aClass className];
    CLHashTableSetData(_nameMapping, pyClass, className, [className hash]);
  }

  return aClass;
}

Class CLClassForPythonObject(PyObject *pyObject)
{
  return CLClassForPythonClass(Py_TYPE(pyObject));
}

#if 0
PyObject *CLNativeToPython(id anObject)
{
  if (!anObject)
    Py_RETURN_NONE;
  return [anObject pythonObject];
}
#endif

static void CLPythonAddToEnvironment(CLDictionary *aDict, CLString **keys)
{
  CLUInteger idx;
  CLString *aString;


  for (idx = 0; keys[idx]; idx++) {
    aString = [aDict objectForKey:keys[idx]];
    if (aString)
      putenv(strdup([[CLString stringWithFormat:@"%@=%@", keys[idx], aString] UTF8String]));
    else
      unsetenv([keys[idx] UTF8String]);
  }

  return;
}

static CLString *CLEnvKeys[] = {
  @"PATH_INFO",
  @"PATH_TRANSLATED",
  @"QUERY_STRING",
  @"SCRIPT_NAME",
  @"SCRIPT_FILENAME",
  @"REQUEST_METHOD",
  @"CONTENT_TYPE",
  @"CONTENT_LENGTH",
  @"DOCUMENT_ROOT",
  @"HTTP_COOKIE",
  @"HTTP_HOST",
  @"HTTP_REFERER",
  @"HTTP_USER_AGENT",
  @"REMOTE_ADDR",
  @"SCRIPT_FILENAME",
  @"SERVER_NAME",
  @"SERVER_PORT",
  @"SERVER_URL",
  nil,
};

static PyObject *CLRun_bridge(PyObject *self, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"mainObjectName", "environment", "stdin", NULL};
  CLAutoreleasePool *pool;
  CLString *mainObjectName = nil;
  CLDictionary *environment = nil;
  CLStream *htmlStream, *headerStream, *inputStream = nil;
  CLUInteger status;
  CLArray *result;
  PyObject *pyResult;


  pool = [[CLAutoreleasePool alloc] init];
  if (!PyArg_ParseTupleAndKeywords(args, kwds, "O&O&|O&", kwlist,
                                   CLPyBridgeConvert, &mainObjectName,
                                   CLPyBridgeConvert, &environment,
                                   CLPyBridgeConvertStream, &inputStream)) {
    [pool release];
    return NULL;
  }

  CLPythonAddToEnvironment(environment, CLEnvKeys);

  // FIXME - get:
  //   * DOCUMENT_ROOT
  //   * HTTP_COOKIE
  //   * HTTP_HOST
  //   * HTTP_REFERER
  //   * HTTP_USER_AGENT
  //   * REMOTE_ADDR
  //   * SCRIPT_FILENAME
  //   * SERVER_NAME
  //   * SERVER_PORT
  //   * SERVER_URL

  htmlStream = [CLStream openMemoryForWriting];
  headerStream = [CLStream openMemoryForWriting];
  status = CLHandleRequest(mainObjectName, htmlStream, headerStream, inputStream);
  [CLDefaultContext saveChanges];

  result = [CLArray arrayWithObjects:[CLNumber numberWithUnsignedInt:status],
                    [htmlStream data], [headerStream data], nil];
  pyResult = CLNativeToPython(result);
  [[CLManager manager] setActiveSession:nil];
  [pool release];

  return pyResult;
}

static PyObject *CLPython_setSessionClass(PyObject *self, PyObject *arg)
{
  PyTypeObject *pyClass = (PyTypeObject *) arg;
  Class aClass;


  if (!PyType_Check(arg)) {
    PyErr_SetString(PyExc_TypeError, "Argument is not a class");
    return NULL;
  }

  aClass = CLClassForPythonClass(pyClass);
  //  aClass = CLClassFromString([CLString stringWithUTF8String:type->tp_name]);
  [CLEditingContext setSessionClass:aClass];
  Py_RETURN_NONE;
}

static PyObject *CLPython_saveChanges(PyObject *self, PyObject *Py_UNUSED(ignored))
{
  [CLDefaultContext saveChanges];
  Py_RETURN_NONE;
}

static PyMethodDef ClearLake_functions[] = {
  {"run", (PyCFunction) CLRun_bridge, METH_VARARGS | METH_KEYWORDS,
   "handle a request from a client"},
  {"setSessionClass", CLPython_setSessionClass, METH_O, "set the class used for sessions"},
  {"saveChanges", (PyCFunction) CLPython_saveChanges, METH_NOARGS,
    "save any objects to the database that have been changed"},
  {NULL},
};

static PyModuleDef ClearLake_module = {
  .m_base = PyModuleDef_HEAD_INIT,
  .m_name = "ClearLake",
  .m_doc = "ClearLake",
  .m_size = sizeof(ClearLake_python_state),
  .m_methods = ClearLake_functions,
};

PyMODINIT_FUNC PyInit_ClearLake(void)
{
  PyObject *m;
  ClearLake_python_state *state;
  CLUInteger idx;


  _classMapping = CLHashTableAlloc(CLHashTableDefaultSize);
  _nameMapping = CLHashTableAlloc(CLHashTableDefaultSize);

  for (idx = 0; CLBridgeTypes[idx].name; idx++) {
    if (PyType_Ready(CLBridgeTypes[idx].type) < 0)
      return NULL;
  }

  m = PyModule_Create(&ClearLake_module);
  if (m == NULL)
    return NULL;

  for (idx = 0; CLBridgeTypes[idx].name; idx++) {
    if (PyModule_AddObjectRef(m, CLBridgeTypes[idx].name,
			      (PyObject *) CLBridgeTypes[idx].type) < 0) {
      Py_DECREF(m);
      return NULL;
    }
  }

  state = (ClearLake_python_state *) PyModule_GetState(m);
  state->pool = [[CLAutoreleasePool alloc] init];

  objc_setGetUnknownClassHandler(CLPyBridgeClassFromName);

  return m;
}
