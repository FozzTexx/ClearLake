#import "CLArrayBridge.h"

@implementation CLArray (CLPythonExtensions)

-(PyObject *) pythonObject
{
  PyObject *py_tuple;
  CLUInteger idx, count;


  count = [self count];
  py_tuple = PyTuple_New(count);
  for (idx = 0; idx < count; idx++) {
    if (PyTuple_SetItem(py_tuple, idx, [[self objectAtIndex:idx] pythonObject]) != 0) {
      PyErr_SetString(PyExc_Exception, "Failed to set tuple item");
      Py_DECREF(py_tuple);
      return NULL;
    }
  }

  return py_tuple;
}

@end
