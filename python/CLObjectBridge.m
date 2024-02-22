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

+(id) alloc
{
  CLClassDef *hack;
  id new;


  hack = (CLClassDef *) self;
  new = [super alloc];
  printf("Allocating for python %s %x\n", hack->name, new);
  return new;
}

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

-(id) init
{
  PyObject *py_class;
  CLString *className;
  CLClassDef *hack;


  [super init];
  
  hack = (CLClassDef *) [self class];
  className = [CLUTF8String stringWithUTF8String:hack->name];
  py_class = CLPythonClassFromString(className);
  if (!py_class)
    [self error:@"Not implemented %@", className];

  pythonObject = PyObject_CallObject(py_class, NULL);
  if (!pythonObject)
    [self error:@"Unable to create instance of %@", className];
  printf("Bridge pythonObject: %x %x\n", self, pythonObject);

  return self;
}

-(id) initWithPythonObject:(PyObject *) pyObject
{
  if (pythonObject)
    [self error:@"Already called init"];
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

-(id) read:(CLStream *) stream
{
  [super read:stream];
  [self init];
  return self;
}
  
-(void) write:(CLStream *) stream
{
  [super write:stream];
  return;
}

-(PyObject *) pythonObject
{
  return pythonObject;
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
  if (PyObject_HasAttr(pythonObject, pyBinding)) {
    attr = PyObject_GetAttr(pythonObject, pyBinding);
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
  attr = PyObject_GetAttrString(pythonObject, [aBinding UTF8String]);

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

  Py_DECREF(attr);

  [anInvocation setReturnValue:&anObject];
  
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

  return aString;
}

@end

int CLPythonConvert(PyObject *anObj, void *address)
{
  *(id *) address = [CLObjectBridge objectWithPythonObject:anObj];
  return 1;
}
