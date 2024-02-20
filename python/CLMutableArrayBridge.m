#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <datetime.h>

#import "CLMutableArrayBridge.h"
#import "CLObjectBridge.h"

@implementation CLMutableArray (CLPythonExtensions)

+(id) arrayWithPythonObject:(PyObject *) pyList
{
  return [[[CLMutableArrayBridge alloc] initWithPythonObject:pyList] autorelease];
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
