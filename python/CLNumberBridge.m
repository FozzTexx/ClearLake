#import "CLNumberBridge.h"
#import <ClearLake/CLNumber.h>
#import <ClearLake/CLString.h>

@implementation CLNumber (CLPythonExtensions)

-(PyObject *) pythonObject
{
  switch (type) {
  case 'i':
    return PyLong_FromLong(value.l);
  case 'u':
    return PyLong_FromUnsignedLong(value.ul);
  case 'd':
    return PyLong_FromDouble(value.d);
  }

  [self error:@"Unable to convert type: %c\n", type];
  Py_RETURN_NONE;
}

@end
