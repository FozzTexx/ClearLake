#import "CLArrayBridge.h"
#import "CLPythonModule.h"
#import "CLPythonBridge.h"
#import "CLMutableArrayBridge.h"
#import <ClearLake/CLArray.h>
#import <ClearLake/CLString.h>

@implementation CLArray (CLPythonExtensions)

+(id) arrayWithPythonObject:(PyObject *) pyTuple
{
  CLUInteger idx, count;
  id *buf;


  if (!PyTuple_Check(pyTuple))
    [self error:@"object is not a Python tuple"];

  count = PyTuple_Size(pyTuple);
  buf = alloca(sizeof(id) * count);
  for (idx = 0; idx < count; idx++)
    buf[idx] = CLPythonToNative(PyTuple_GetItem(pyTuple, idx));

  return [CLArray arrayWithObjects:buf count:count];
}

-(PyObject *) pythonObject
{
  PyObject *pyTuple = NULL;


  CLPythonTupleFromArray(self, &pyTuple);
  return pyTuple;
}

@end

/* For some reason trying to return a PyObject * ends up with the
   pointer address mangled. Passing the address through a PyObject **
   avoids the corruption. Not sure what's going on. */
void CLPythonTupleFromArray(CLArray *anArray, PyObject **pyObject)
{
  PyObject *pyTuple, *value;
  CLUInteger idx, count;


  count = [anArray count];
  pyTuple = PyTuple_New(count);
  for (idx = 0; idx < count; idx++) {
    value = CLNativeToPython([anArray objectAtIndex:idx]);
    if (PyTuple_SetItem(pyTuple, idx, value) != 0) {
      PyErr_SetString(PyExc_Exception, "Failed to set tuple item");
      Py_DECREF(pyTuple);
      return;
    }
  }

  *pyObject = pyTuple;
  return;
}

PyObject *CLPythonListFromArray(CLArray *anArray)
{
  PyObject *pyList, *value;
  CLUInteger idx, count;


  count = [anArray count];
  pyList = PyList_New(count);
  for (idx = 0; idx < count; idx++) {
    value = CLNativeToPython([anArray objectAtIndex:idx]);
    if (PyList_SetItem(pyList, idx, value) != 0) {
      PyErr_SetString(PyExc_Exception, "Failed to set tuple item");
      Py_DECREF(pyList);
      return NULL;
    }
  }

  return pyList;
}
