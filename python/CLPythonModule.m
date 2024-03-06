#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <stdlib.h>

#import "CLPythonModule.h"
#import "CLManagerBridge.h"
#import "CLPageBridge.h"
#import "CLFormBridge.h"
#import "CLOptionBridge.h"
#import "CLArrayBridge.h"
#import "CLStreamBridge.h"
#import "CLControlBridge.h"
#import "CLOriginalFileBridge.h"
#import "CLSessionBridge.h"

#import <ClearLake/CLAutoreleasePool.h>
#import <ClearLake/CLDictionary.h>
#import <ClearLake/CLString.h>
#import <ClearLake/CLStream.h>
#import <ClearLake/CLManager.h>
#import <ClearLake/CLNumber.h>
#import <ClearLake/CLRuntime.h>
#import <ClearLake/CLEditingContext.h>

#define BRIDGE_TYPE(x) {#x, (PyTypeObject *) &x##BridgeType}

static struct {
  char *name;
  PyTypeObject *type;
} CLBridgeTypes[] = {
  BRIDGE_TYPE(CLObject),
  BRIDGE_TYPE(CLManager),
  BRIDGE_TYPE(CLPage),
  BRIDGE_TYPE(CLForm),
  BRIDGE_TYPE(CLOption),
  BRIDGE_TYPE(CLControl),
  BRIDGE_TYPE(CLOriginalFile),
  BRIDGE_TYPE(CLSession),
  {NULL, NULL},
};

typedef struct {
  CLAutoreleasePool *pool;
} ClearLake_python_state;

static CLHashTable *_classMapping = NULL;

Class (*CLClassFromString_python_orig)(CLString *);

Class CLClassFromString_python(CLString *aString)
{
  Class aClass;
  CLClassDef *hack;
  PyObject *pyClass;


  aClass = CLClassFromString_python_orig(aString);
  if (!aClass) {
    aClass = CLHashTableDataForKey(_classMapping, aString, [aString hash],
				   @selector(isEqual:));
    if (!aClass && (pyClass = CLPythonClassFromString(aString))) {
      hack = malloc(sizeof(CLClassDef));
      aClass = CLNativeSuperclassForPythonClass(pyClass);
      if (!aClass)
	aClass = [CLObjectBridge class];
      memcpy(hack, [CLObjectBridge class], sizeof(CLClassDef));
      hack->name = strdup([[CLString stringWithFormat:@"%@:%@", [aClass className], aString]
			    UTF8String]);
      aClass = (Class) hack;
      aString = [aString copy]; // copy not retain in case string is mutable
      CLHashTableSetData(_classMapping, aClass, aString, [aString hash]);
    }
  }

  return aClass;
}

#if 0
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

PyObject *CLPythonClassFromString(CLString *aString)
{
  PyObject *main_module, *main_dict, *pyClass;


  main_module = PyImport_AddModule("__main__");
  main_dict = PyModule_GetDict(main_module);
  //print_dict_keys(main_dict);
  pyClass = PyDict_GetItemString(main_dict, [aString UTF8String]);
  return pyClass;
}

BOOL CLIsBridgeClass(PyTypeObject *pyType)
{
  CLUInteger idx;


  for (idx = 0; CLBridgeTypes[idx].name; idx++) {
    if (CLBridgeTypes[idx].type == pyType)
      return YES;
  }

  return NO;
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

Class CLNativeSuperclassForPythonClass(PyObject *pyClass)
{
  CLUInteger idx;
  PyTypeObject *type = pyClass;


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

Class CLClassForPythonObject(PyObject *pyObject)
{
  return CLClassFromString([CLString stringWithUTF8String:pyObject->ob_type->tp_name]);
}

PyObject *CLPythonObjectForNativeObject(id anObject)
{
  if (!anObject)
    Py_RETURN_NONE;
  return [anObject pythonObject];
}

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
                                   CLPythonConvert, &mainObjectName,
                                   CLPythonConvert, &environment,
                                   CLPythonConvertStream, &inputStream)) {
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

  result = [CLArray arrayWithObjects:[CLNumber numberWithUnsignedInt:status],
                    [htmlStream data], [headerStream data], nil];
  pyResult = [result pythonObject];
  [[CLManager manager] setActiveSession:nil];
  [pool release];

  return pyResult;
}

static PyObject *CLPython_setSessionClass(PyObject *self, PyObject *arg)
{
  PyTypeObject *type = (PyTypeObject *) arg;
  Class aClass;


  if (!PyType_Check(arg)) {
    PyErr_SetString(PyExc_TypeError, "Argument is not a class");
    return NULL;
  }

  aClass = CLClassFromString([CLString stringWithUTF8String:type->tp_name]);
  [CLEditingContext setSessionClass:aClass];
  Py_RETURN_NONE;
}

static PyObject *CLPython_saveChanges(CLObjectLink *self, PyObject *Py_UNUSED(ignored))
{
  [CLDefaultContext saveChanges];
  Py_RETURN_NONE;
}

static PyMethodDef ClearLake_functions[] = {
  {"CLRun", (PyCFunction) CLRun_bridge, METH_VARARGS | METH_KEYWORDS,
   "handle the request from a client"},
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

  CLClassFromString_python_orig = CLClassFromString;
  CLClassFromString = CLClassFromString_python;

  return m;
}
