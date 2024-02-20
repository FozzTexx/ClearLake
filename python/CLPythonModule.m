#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <datetime.h>

#import <ClearLake/CLAutoreleasePool.h>
#import "CLPageBridge.h"
#import "CLOptionBridge.h"

typedef struct {
  CLAutoreleasePool *pool;
} ClearLake_python_state;

static PyModuleDef ClearLake_module = {
  .m_base = PyModuleDef_HEAD_INIT,
  .m_name = "ClearLake",
  .m_doc = "ClearLake",
  .m_size = sizeof(ClearLake_python_state),
};

PyMODINIT_FUNC PyInit_ClearLake(void)
{
  PyObject *m;
  ClearLake_python_state *state;


  if (PyType_Ready(&CLPageBridgeType) < 0)
    return NULL;
  if (PyType_Ready(&CLOptionBridgeType) < 0)
    return NULL;

  m = PyModule_Create(&ClearLake_module);
  if (m == NULL)
    return NULL;

  if (PyModule_AddObjectRef(m, "CLPage", (PyObject *) &CLPageBridgeType) < 0) {
    Py_DECREF(m);
    return NULL;
  }
  if (PyModule_AddObjectRef(m, "CLOption", (PyObject *) &CLOptionBridgeType) < 0) {
    Py_DECREF(m);
    return NULL;
  }

  state = (ClearLake_python_state *) PyModule_GetState(m);
  state->pool = [[CLAutoreleasePool alloc] init];
  
  return m;
}
