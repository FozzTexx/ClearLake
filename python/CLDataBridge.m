#import "CLDataBridge.h"

@implementation CLData (CLPythonExtensions)

-(PyObject *) pythonObject
{
  return PyBytes_FromStringAndSize([self bytes], [self length]);
}

@end
