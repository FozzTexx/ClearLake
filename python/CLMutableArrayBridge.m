#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import "CLMutableArrayBridge.h"
#import "CLPythonModule.h"
#import "CLPythonBridge.h"
#import "CLArrayBridge.h"

#import <ClearLake/CLConstantString.h>

@implementation CLMutableArray (CLPythonExtensions)

+(id) arrayWithPythonObject:(PyObject *) pyList
{
  return [[[CLMutableArrayBridge alloc] initWithPythonObject:pyList] autorelease];
}

#if 1
-(PyObject *) pythonObject
{
  PyObject *pyTuple = NULL;


  CLPythonTupleFromArray(self, &pyTuple);
  return pyTuple;
}
#else
-(PyObject *) pythonObject
{
  [self error:@"Not implemented"];
  return NULL;
}
#endif

@end

@implementation CLMutableArrayBridge

-(id) initWithPythonObject:(PyObject *) pyObject
{
  if (!PyList_Check(pyObject))
    [self error:@"object is not a Python list"];
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
  return CLPythonToNative(PyList_GetItem(arrayData, index));
}

-(void) write:(CLStream *) stream
{
  CLArray *anArray = [[CLArray alloc] initWithArray:self];


  [anArray write:stream];
  [anArray release];
  return;
}

@end
