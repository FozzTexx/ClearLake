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
