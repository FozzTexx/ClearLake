#import "CLDataBridge.h"
#import <ClearLake/CLData.h>

@implementation CLData (CLPythonExtensions)

+(id) dataFromPythonObject:(PyObject *) pyBytes
{
  return [[[self alloc] initFromPythonObject:pyBytes] autorelease];
}

-(id) initFromPythonObject:(PyObject *) pyBytes
{
  return [self initWithBytes:PyBytes_AsString(pyBytes) length:PyBytes_Size(pyBytes)];
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
