#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <datetime.h>
#include <stdlib.h>

#import "CLPythonModule.h"
#import "CLPageBridge.h"
#import "CLFormBridge.h"
#import "CLOptionBridge.h"
#import "CLArrayBridge.h"
#import "CLStreamBridge.h"
#import "CLControlBridge.h"

#import <ClearLake/CLAutoreleasePool.h>
#import <ClearLake/CLDictionary.h>
#import <ClearLake/CLString.h>
#import <ClearLake/CLStream.h>
#import <ClearLake/CLManager.h>
#import <ClearLake/CLNumber.h>
#import <ClearLake/CLRuntime.h>

typedef struct {
  CLAutoreleasePool *pool;
} ClearLake_python_state;

Class (*CLClassFromString_python_orig)(CLString *);

Class CLClassFromString_python(CLString *aString)
{
  Class aClass;
  CLClassDef *hack;
  PyObject *py_class;


  aClass = CLClassFromString_python_orig(aString);
  if (!aClass) {
    if ((py_class = CLPythonClassFromString(aString))) {
      hack = malloc(sizeof(CLClassDef));
      memcpy(hack, [CLObjectBridge class], sizeof(CLClassDef));
      hack->name = strdup([aString UTF8String]);
      aClass = (Class) hack;
    }
  }

  return aClass;
}

PyObject *CLPythonClassFromString(CLString *aString)
{
  PyObject *main_module, *main_dict, *py_class;


  main_module = PyImport_AddModule("__main__");
  main_dict = PyModule_GetDict(main_module);
  py_class = PyDict_GetItemString(main_dict, [aString UTF8String]);
  return py_class;
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
  @"REQUEST_METHOD",
  @"CONTENT_TYPE",
  @"CONTENT_LENGTH",
  nil,
};

static PyObject* CLRun_bridge(PyObject *self, PyObject *args, PyObject *kwds)
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
  [pool release];

  return pyResult;
}

static PyMethodDef ClearLake_functions[] = {
  {"CLRun", CLRun_bridge, METH_VARARGS | METH_KEYWORDS, "handle the request from a client"},
  {NULL, NULL, 0, NULL}  // Sentinel
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


  if (PyType_Ready(&CLPageBridgeType) < 0)
    return NULL;
  if (PyType_Ready(&CLFormBridgeType) < 0)
    return NULL;
  if (PyType_Ready(&CLOptionBridgeType) < 0)
    return NULL;
  if (PyType_Ready(&CLControlBridgeType) < 0)
    return NULL;

  m = PyModule_Create(&ClearLake_module);
  if (m == NULL)
    return NULL;

  if (PyModule_AddObjectRef(m, "CLPage", (PyObject *) &CLPageBridgeType) < 0) {
    Py_DECREF(m);
    return NULL;
  }
  if (PyModule_AddObjectRef(m, "CLForm", (PyObject *) &CLFormBridgeType) < 0) {
    Py_DECREF(m);
    return NULL;
  }
  if (PyModule_AddObjectRef(m, "CLOption", (PyObject *) &CLOptionBridgeType) < 0) {
    Py_DECREF(m);
    return NULL;
  }
  if (PyModule_AddObjectRef(m, "CLControl", (PyObject *) &CLControlBridgeType) < 0) {
    Py_DECREF(m);
    return NULL;
  }

  state = (ClearLake_python_state *) PyModule_GetState(m);
  state->pool = [[CLAutoreleasePool alloc] init];

  CLClassFromString_python_orig = CLClassFromString;
  CLClassFromString = CLClassFromString_python;

  return m;
}
