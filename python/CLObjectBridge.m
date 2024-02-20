#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <datetime.h>

#import <ClearLake/CLInvocation.h>
#import <ClearLake/CLNumber.h>

#import "CLObjectBridge.h"
#import "CLStringBridge.h"
#import "CLMutableArrayBridge.h"
#import "CLPageBridge.h"
#import "CLOptionBridge.h"

@implementation CLObjectBridge

+(BOOL) isBridgeClass:(PyObject *) pyObject
{
  return pyObject->ob_type == &CLPageBridgeType
    || pyObject->ob_type == &CLOptionBridgeType;
}

+(id) objectWithPythonObject:(PyObject *) pyObject
{
  id value = nil;


  PyDateTime_IMPORT;
  
  if (!pyObject || pyObject == Py_None)
    value = nil;
  else if (PyLong_Check(pyObject))
    value = [CLNumber numberWithLongLong:PyLong_AsLongLong(pyObject)];
  else if (PyFloat_Check(pyObject))
    value = [CLNumber numberWithDouble:PyFloat_AsDouble(pyObject)];
  else if (PyUnicode_Check(pyObject))
    value = [CLString stringFromPythonObject:pyObject];
  else if (PyTuple_Check(pyObject))
    [self error:@"Conversion to CLArray not implemented"];
  else if (PyList_Check(pyObject))
    value = [CLMutableArray arrayWithPythonObject:pyObject];
  else if (PyBytes_Check(pyObject))
    [self error:@"Conversion to CLData not implemented"];
  else if (PyDateTime_Check(pyObject))
    [self error:@"Conversion to CLDatetime not implemented"];
  else if (PyDict_Check(pyObject))
    [self error:@"Conversion to CLMutableDictionary not implemented"];
  else if (PySet_Check(pyObject))
    [self error:@"There's no set class in ClearLake!"];
  else if ([self isBridgeClass:pyObject])
    value = ((CLBridgeObject *) pyObject)->bridgeObject;
  else
    value = [[[self alloc] initWithPythonObject:pyObject] autorelease];

  return value;
}

-(id) initWithPythonObject:(PyObject *) pyObject
{
  [super init];
  Py_INCREF(pyObject);
  pythonObject = pyObject;
  return self;
}

-(void) dealloc
{
  Py_DECREF(pythonObject);
  [super dealloc];
  return;
}

-(id) objectValueForBinding:(CLString *) aBinding found:(BOOL *) found
{
  id value;
  PyObject *result, *attr;
  PyObject *pyBinding;


  value = [super objectValueForBinding:aBinding found:found];
  
  if (!*found) {
    pyBinding = [aBinding pythonObject];
    if (PyObject_HasAttr(pythonObject, pyBinding)) {
      *found = YES;
      attr = PyObject_GetAttr(pythonObject, pyBinding);
      if (PyCallable_Check(attr)) {
	result = PyObject_CallObject(attr, NULL);
      }
      else {
	Py_INCREF(attr);
	result = attr;
      }
      
      //[self error:@"Unable to find value %@ %@", [self className], aBinding];
      Py_DECREF(attr);
      Py_DECREF(pyBinding);

      value = [CLObjectBridge objectWithPythonObject:result];

      if (result)
	Py_DECREF(result);
    }
  }

  return value;
}
    
-(void) forwardInvocation:(CLInvocation *) anInvocation
{
  CLString *aBinding;


  aBinding = CLSelGetName([anInvocation selector]);
  [self error:@"Unable to forward %@ %@", [self className], aBinding];
  // FIXME - figure out what method was called and pass it along to pythonObject
  // FIXME - convert returned value as needed
  return;
}

-(CLString *) className
{
  PyObject *classObj, *name;
  CLString *aString;


  classObj = PyObject_GetAttrString(pythonObject, "__class__");
  if (!classObj)
    return nil;

  name = PyObject_GetAttrString(classObj, "__name__");
  Py_DECREF(classObj);
  if (!name)
    return nil;

  aString = [CLString stringFromPythonObject:name];
  Py_DECREF(name);

  return [CLString stringWithFormat:@"PyObject_%@", aString];
}

@end

int CLObjectBridgeConvert(PyObject *anObj, void *address)
{
  *(id *) address = [CLObjectBridge objectWithPythonObject:anObj];
  return 1;
}
