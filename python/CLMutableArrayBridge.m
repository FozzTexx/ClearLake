#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import "CLMutableArrayBridge.h"
#import "CLObjectBridge.h"

#import <ClearLake/CLConstantString.h>

@implementation CLMutableArray (CLPythonExtensions)

+(id) arrayWithPythonObject:(PyObject *) pyList
{
  return [[[CLMutableArrayBridge alloc] initWithPythonObject:pyList] autorelease];
}

-(PyObject *) pythonObject
{
  CLObjectLink *obj;
  PyTypeObject *type;


  type = CLPythonBridgeTypeForClass([self class]);
  if (!type)
    type = &CLObjectBridgeType;

  obj = (CLObjectLink *) type->tp_new(type, PyTuple_New(0), NULL);
  obj->bridgeObject = [self retain];
  return (PyObject *) obj;
}

@end

@implementation CLMutableArrayBridge

-(id) initWithPythonObject:(PyObject *) pyObject
{
  [super init];
  Py_INCREF(pyObject);
  arrayData = pyObject;
  return self;
}

-(void) dealloc
{
  Py_DECREF(arrayData);
  [super dealloc];
  return;
}

-(CLUInteger) count
{
  return PyList_Size(arrayData);
}

-(id) objectAtIndex:(CLUInteger) index
{
  return [CLObjectBridge objectWithPythonObject:PyList_GetItem(arrayData, index)];
}

@end
