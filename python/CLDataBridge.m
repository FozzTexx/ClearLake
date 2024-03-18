#import "CLDataBridge.h"
#import <ClearLake/CLData.h>
#import <ClearLake/CLString.h>

@implementation CLData (CLPythonExtensions)

+(id) dataFromPythonObject:(PyObject *) pyBytes
{
  return [[[self alloc] initFromPythonObject:pyBytes] autorelease];
}

-(id) initFromPythonObject:(PyObject *) pyBytes
{
  char *buf;
  Py_ssize_t length;


  if (PyBytes_Check(pyBytes))
    PyBytes_AsStringAndSize(pyBytes, &buf, &length);
  else if (PyByteArray_Check(pyBytes)) {
    buf = PyByteArray_AsString(pyBytes);
    length = PyByteArray_Size(pyBytes);
  }
  else
    [self error:@"Not a bytes or bytearray"];

  return [self initWithBytes:buf length:length];
}

-(PyObject *) pythonObject
{
  return PyBytes_FromStringAndSize([self bytes], [self length]);
}

@end

int CLPyBridgeConvertData(PyObject *anObj, void *address)
{
  if (!PyBytes_Check(anObj) && !PyByteArray_Check(anObj)) {
    PyErr_SetString(PyExc_TypeError, "argument must be bytes or bytearray");
    return 0;
  }

  *(id *) address = [CLData dataFromPythonObject:anObj];
  return 1;
}
