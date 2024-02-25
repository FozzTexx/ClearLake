#import "CLStringBridge.h"

@implementation CLString (CLPythonExtensions)

+(id) stringFromPythonObject:(PyObject *) pyString
{
  return [[[self alloc] initFromPythonObject:pyString] autorelease];
}

-(id) initFromPythonObject:(PyObject *) pyString
{
  return [self initWithUTF8String:PyUnicode_AsUTF8(pyString)];
}

-(PyObject *) pythonObject
{
  return PyUnicode_FromString([self UTF8String]);
}

@end

int CLPythonConvertString(PyObject *anObj, void *address)
{
  if (!PyUnicode_Check(anObj)) {
    PyErr_SetString(PyExc_TypeError, "argument must be str");
    return 0;
  }

  *(id *) address = [CLString stringFromPythonObject:anObj];
  return 1;
}
