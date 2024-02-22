#import "CLNumberBridge.h"

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

  Py_RETURN_NONE;
}

@end
