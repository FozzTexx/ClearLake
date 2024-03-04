#import "CLDataBridge.h"
#import <ClearLake/CLData.h>

@implementation CLData (CLPythonExtensions)

-(PyObject *) pythonObject
{
  return PyBytes_FromStringAndSize([self bytes], [self length]);
}

@end
