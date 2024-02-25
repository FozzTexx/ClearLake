#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <datetime.h>

#import <ClearLake/CLInvocation.h>
#import <ClearLake/CLNumber.h>
#import <ClearLake/CLMutableString.h>
#import <ClearLake/CLMethodSignature.h>

#import "CLObjectBridge.h"
#import "CLStringBridge.h"
#import "CLMutableArrayBridge.h"
#import "CLPageBridge.h"
#import "CLOptionBridge.h"
#import "CLMutableDictionaryBridge.h"
#import "CLPythonModule.h"

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
    value = [CLMutableDictionary dictionaryWithPythonObject:pyObject];
  else if (PySet_Check(pyObject))
    [self error:@"There's no set class in ClearLake!"];
  else if ([self isBridgeClass:pyObject])
    value = ((CLObjectLink *) pyObject)->bridgeObject;
  else
    value = [[[self alloc] initWithPythonObject:pyObject] autorelease];

  return value;
}

-(CLString *) pythonClassName
{
  CLString *className, *prefix;
  CLClassDef *hack;


  [super init];

  prefix = [CLString stringWithFormat:@"%@_", [[self class] className]];
  hack = (CLClassDef *) [self class];
  className = [CLUTF8String stringWithUTF8String:hack->name];
  if (![className hasPrefix:prefix])
    [self error:@"Trying to init unrecognized class %@", className];
  className = [className substringFromIndex:[prefix length]];
  return className;
}
  
-(id) init
{
  PyObject *pyClass, *pyObject;
  CLString *className;


  className = [self pythonClassName];
  pyClass = CLPythonClassFromString(className);
  if (!pyClass)
    [self error:@"No such python class: %@", className];

  pyObject = PyObject_CallObject(pyClass, NULL);
  [self initWithPythonObject:pyObject];
  Py_DECREF(pyObject);

  return self;
}

-(id) initWithPythonObject:(PyObject *) pyObject
{
  if (!pyObject)
    [self error:@"init with what?"];
  if (bridged)
    [self error:@"Already called init"];

  [super init];
  Py_INCREF(pyObject);
  bridged = pyObject;
  return self;
}

-(void) dealloc
{
  Py_DECREF(bridged);
  [super dealloc];
  return;
}

-(id) read:(CLStream *) stream
{
  id anObject;


  [super read:stream];
  [self init];
  [stream readType:@"@" data:&anObject];
  [self setObjectValue:anObject forBinding:@"__setstate__"];
  return self;
}

-(void) write:(CLStream *) stream
{
  id anObject;


  [super write:stream];
  anObject = [self objectValueForBinding:@"__getstate__"];
  [stream writeType:@"@" data:&anObject];
  return;
}

-(PyObject *) pythonObject
{
  return bridged;
}

-(id) objectValueForBinding:(CLString *) aBinding found:(BOOL *) found
{
  id value;
  PyObject *result, *attr;
  PyObject *pyBinding;


  value = [super objectValueForBinding:aBinding found:found];

  if (!*found) {
    pyBinding = [aBinding pythonObject];
    if (PyObject_HasAttr(bridged, pyBinding)) {
      *found = YES;
      attr = PyObject_GetAttr(bridged, pyBinding);
      if (PyCallable_Check(attr)) {
        result = PyObject_CallObject(attr, NULL);
	if (!result) {
	  PyErr_Print();
	  PyErr_Clear();
	}
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

-(CLString *) pythonizeSelector:(SEL) aSel
{
  CLString *aString;


  aString = CLSelGetName(aSel);
  if ([aString hasSuffix:@":"])
    aString = [aString substringToIndex:[aString length] - 1];
  return aString;
}

-(BOOL) respondsTo:(SEL) aSel
{
  PyObject *attr;
  BOOL hasMethod = NO;
  PyObject *pyBinding;


  if ([super respondsTo:aSel])
    return YES;

  pyBinding = [[self pythonizeSelector:aSel] pythonObject];
  if (PyObject_HasAttr(bridged, pyBinding)) {
    attr = PyObject_GetAttr(bridged, pyBinding);
    if (PyCallable_Check(attr))
      hasMethod = YES;
    Py_DECREF(attr);
  }
  Py_DECREF(pyBinding);

  return hasMethod;
}

-(void) forwardInvocation:(CLInvocation *) anInvocation
{
  CLMethodSignature *sig;
  CLString *aBinding;
  PyObject *attr, *result, *py_tuple = NULL;
  CLUInteger idx, count;
  id arg, anObject = nil;


  if (![self respondsTo:[anInvocation selector]])
    [self doesNotRecognize:[anInvocation selector]];

  sig = [anInvocation methodSignature];
  aBinding = [self pythonizeSelector:[anInvocation selector]];
  attr = PyObject_GetAttrString(bridged, [aBinding UTF8String]);

  count = [sig numberOfArguments] - 2;
  if (count) {
    py_tuple = PyTuple_New(count);
    for (idx = 0; idx < count; idx++) {
      arg = [anInvocation objectValueForArgumentAtIndex:idx + 2];
      if (PyTuple_SetItem(py_tuple, idx, [arg pythonObject]) != 0) {
        PyErr_SetString(PyExc_Exception, "Failed to set tuple item");
        [self error:@"Unable to forward %@", aBinding];
      }
    }
  }

  result = PyObject_CallObject(attr, py_tuple);
  if (result) {
    anObject = [[self class] objectWithPythonObject:result];
    Py_DECREF(result);
  }
  else {
    PyErr_Print();
    PyErr_Clear();
  }

  Py_DECREF(attr);

  [anInvocation setReturnValue:&anObject];

  return;
}

#if 1
-(CLString *) className
{
  return [self pythonClassName];
}
#else
-(CLString *) className
{
  PyObject *classObj, *name;


  classObj = PyObject_GetAttrString(pythonObject, "__class__");
  if (!classObj)
    [self error:@"All objects must have a class"];

  name = PyObject_GetAttrString(classObj, "__name__");
  Py_DECREF(classObj);
  if (!name)
    return nil;

  aString = [CLString stringFromPythonObject:name];
  Py_DECREF(name);

  return aString;
}
#endif

@end

int CLPythonConvert(PyObject *anObj, void *address)
{
  *(id *) address = [CLObjectBridge objectWithPythonObject:anObj];
  return 1;
}
