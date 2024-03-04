#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <datetime.h>

#import "CLObjectBridge.h"
#import "CLStringBridge.h"
#import "CLMutableArrayBridge.h"
#import "CLPageBridge.h"
#import "CLOptionBridge.h"
#import "CLMutableDictionaryBridge.h"
#import "CLPythonModule.h"

#import <ClearLake/CLInvocation.h>
#import <ClearLake/CLNumber.h>
#import <ClearLake/CLMutableString.h>
#import <ClearLake/CLMethodSignature.h>
#import <ClearLake/CLGenericRecord.h>
#import <ClearLake/CLStream.h>

@implementation CLObject (CLPythonExtensions)

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

@interface CLObjectBridge (PrivateMethods)
-(BOOL) pythonRespondsTo:(CLString *) aMethod;
@end

@implementation CLObjectBridge

+(id) alloc
{
  CLString *className;
  CLRange aRange;
  id anObject;
  CLObjectReserved *reserved;
  CLBridgeData *data;
  Class aClass;


  className = [CLString stringWithUTF8String:((CLClassDef *)self)->name];
  aRange = [className rangeOfString:@":"];
  if (!aRange.length)
    [self error:@"Unrecognizable class: %@", className];
  className = [className substringToIndex:aRange.location];
  aClass = CLClassFromString(className);

  if (aClass == [CLObjectBridge class])
    anObject = [super alloc];
  else
    anObject = [aClass alloc];

  reserved = ((void *) anObject) - sizeof(CLObjectReserved);
  data = calloc(1, sizeof(CLBridgeData));
  data->originalPrivate = reserved->privateData;
  reserved->privateData = data;
  data->original = aClass;
  ((CLObjectBridge *) anObject)->isa = self;

  return anObject;
}

+(BOOL) isBridgeClass:(PyObject *) pyObject
{
  return CLPythonIsBridgeClass(pyObject->ob_type);
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
  CLString *className;
  CLRange aRange;
  PyObject *pyClass, *pyObject;


  className = [CLString stringWithUTF8String:((CLClassDef *) [self class])->name];
  aRange = [className rangeOfString:@":"];
  if (!aRange.length)
    [self error:@"Unrecognizable class: %@", className];
  className = [className substringFromIndex:CLMaxRange(aRange)];

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
  CLObjectReserved *reserved;
  CLBridgeData *data;
  PyTypeObject *type;
  Class current;


  if (!pyObject)
    [self error:@"init with what?"];

  reserved = ((void *) self) - sizeof(CLObjectReserved);
  data = reserved->privateData;
  data->pyObject = pyObject;
  type = Py_TYPE(pyObject);
  data->pythonClassName = [[CLString alloc] initWithUTF8String:type->tp_name];
  Py_INCREF(pyObject);

  if (data->original == [CLObjectBridge class])
    [super init];
  else {
    current = self->isa;
    self->isa = data->original;
    /* Yes this looks like it could go into an infinite loop but
       this call is to the swizzled class */
    [self init];
    self->isa = current;
  }

  return self;
}

-(void) dealloc
{
  CLObjectReserved *reserved;
  CLBridgeData *data;


  reserved = ((void *) self) - sizeof(CLObjectReserved);
  data = reserved->privateData;
  Py_DECREF(data->pyObject);
  reserved->privateData = data->originalPrivate;
  free(data);
  [super dealloc];
  return;
}

-(id) read:(CLStream *) stream
{
  id anObject;


  [super read:stream];
  [self init];
  [stream readType:@"@" data:&anObject];
  if ([self pythonRespondsTo:@"__setstate__"])
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
  CLObjectReserved *reserved;
  CLBridgeData *data;


  reserved = ((void *) self) - sizeof(CLObjectReserved);
  data = reserved->privateData;
  return data->pyObject;
}

-(id) objectValueForBinding:(CLString *) aBinding found:(BOOL *) found
{
  id value = nil;
  PyObject *result, *attr;
  PyObject *pyBinding;
  CLObjectReserved *reserved;
  CLBridgeData *data;
  Class current;


  reserved = ((void *) self) - sizeof(CLObjectReserved);
  data = reserved->privateData;

  if (data->original != [CLObjectBridge class]) {
    current = self->isa;
    self->isa = data->original;
    /* Yes this looks like it could go into an infinite loop but
       this call is to the swizzled class */
    value = [self objectValueForBinding:aBinding found:found];
    self->isa = current;
  }

  if (!*found) {
    pyBinding = [aBinding pythonObject];
    if (PyObject_HasAttr(data->pyObject, pyBinding)) {
      *found = YES;
      attr = PyObject_GetAttr(data->pyObject, pyBinding);
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

-(void) setObjectValue:(id) anObject forVariable:(CLString *) aField
{
  [self error:@"Not implemented"];
  return;
}

-(void) setObjectValue:(id) anObject forBinding:(CLString *) aBinding
{
  CLObjectReserved *reserved;
  CLBridgeData *data;
  Class current;
  CLRange aRange;
  id anObject2;
  SEL sel;
  int aType;
  BOOL found = NO;
  CLString *setBinding;


  reserved = ((void *) self) - sizeof(CLObjectReserved);
  data = reserved->privateData;

  aRange = [aBinding rangeOfString:@"." options:0 range:CLMakeRange(0, [aBinding length])];
  if (aRange.length) {
    anObject2 = [self objectValueForBinding:[aBinding substringToIndex:aRange.location]];
    [anObject2 setObjectValue:anObject forBinding:[aBinding
						    substringFromIndex:CLMaxRange(aRange)]];
  }
  else {
    setBinding = [CLString stringWithFormat:@"set%@:", [aBinding upperCamelCaseString]];
    sel = sel_getUid([setBinding UTF8String]);

    current = self->isa;
    self->isa = data->original;
    if ([self respondsTo:sel] || [self pointerForIvar:[aBinding UTF8String] type:&aType]) {
      /* Yes this looks like it could go into an infinite loop but
	 this call is to the swizzled class */
      [self setObjectValue:anObject forBinding:aBinding];
      found = YES;
    }
    self->isa = current;

    if (!found) {
      PyObject *pyBinding, *attr;


      pyBinding = [aBinding pythonObject];
      if (PyObject_HasAttr(data->pyObject, pyBinding)) {
	attr = PyObject_GetAttr(data->pyObject, pyBinding);
	if (PyCallable_Check(attr)) {
	  [self error:@"Let forwardInvocation: do it?"];
	}
	else {
	  [self error:@"Set the python attribute"];
	}

	Py_DECREF(attr);
      }
      else {
	PyObject *value;


	value = [anObject pythonObject];
	if (!value) {
	  value = Py_None;
	  Py_INCREF(value);
	}
	if (PyObject_SetAttrString(data->pyObject, [aBinding UTF8String], value) < 0) {
	  [self error:@"Unable to set attribute of python object"];
	}
	Py_DECREF(value);
      }

      Py_DECREF(pyBinding);
    }
  }

  return;
}

-(CLString *) pythonizeSelector:(SEL) aSel
{
  CLString *aString;


  aString = CLSelGetName(aSel);
  if ([aString hasSuffix:@":"])
    aString = [aString substringToIndex:[aString length] - 1];
  return aString;
}

-(BOOL) pythonRespondsTo:(CLString *) aMethod
{
  PyObject *attr;
  BOOL hasMethod = NO;
  PyObject *pyBinding;
  CLObjectReserved *reserved;
  CLBridgeData *data;


  reserved = ((void *) self) - sizeof(CLObjectReserved);
  data = reserved->privateData;

  pyBinding = [aMethod pythonObject];
  if (PyObject_HasAttr(data->pyObject, pyBinding)) {
    attr = PyObject_GetAttr(data->pyObject, pyBinding);
    if (PyCallable_Check(attr))
      hasMethod = YES;
    Py_DECREF(attr);
  }
  Py_DECREF(pyBinding);

  return hasMethod;
}

-(BOOL) respondsTo:(SEL) aSel
{
  CLObjectReserved *reserved;
  CLBridgeData *data;


  reserved = ((void *) self) - sizeof(CLObjectReserved);
  data = reserved->privateData;

  if (class_getInstanceMethod(data->original, aSel)
      || [self pythonRespondsTo:[self pythonizeSelector:aSel]])
    return YES;

  return NO;
}

+(void) forwardInvocation:(CLInvocation *) anInvocation
{
  CLString *className;
  CLRange aRange;
  id anObject;
  CLObjectReserved *reserved;
  CLBridgeData *data;
  Class aClass;


  className = [CLString stringWithUTF8String:((CLClassDef *)self)->name];
  aRange = [className rangeOfString:@":"];
  if (!aRange.length)
    [self error:@"Unrecognizable class: %@", className];
  className = [className substringToIndex:aRange.location];
  aClass = CLClassFromString(className);

  if (![aClass respondsTo:[anInvocation selector]])
    [self doesNotRecognize:[anInvocation selector]];

  [anInvocation invokeWithTarget:aClass];

  return;
}

-(void) forwardInvocation:(CLInvocation *) anInvocation
{
  CLMethodSignature *sig;
  CLString *aBinding;
  PyObject *attr, *result, *py_tuple = NULL;
  CLUInteger idx, count;
  id arg, anObject = nil;
  CLObjectReserved *reserved;
  CLBridgeData *data;
  Class current;


  if (![self respondsTo:[anInvocation selector]])
    [self doesNotRecognize:[anInvocation selector]];

  reserved = ((void *) self) - sizeof(CLObjectReserved);
  data = reserved->privateData;
  if (class_getInstanceMethod(data->original, [anInvocation selector])) {
    current = self->isa;
    self->isa = data->original;
    [anInvocation invoke];
    self->isa = current;
    return;
  }

  sig = [anInvocation methodSignature];
  aBinding = [self pythonizeSelector:[anInvocation selector]];
  attr = PyObject_GetAttrString(data->pyObject, [aBinding UTF8String]);

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

-(IMP) methodFor:(SEL) aSel
{
  CLBridgeData *data;
  CLObjectReserved *reserved;


  reserved = (void *) self - sizeof(CLObjectReserved);
  data = reserved->privateData;

  return method_getImplementation(class_getInstanceMethod(data->original, aSel));
}

-(struct objc_method_description *) descriptionForMethod:(SEL) aSel
{
  CLObjectReserved *reserved;
  CLBridgeData *data;


  reserved = (void *) self - sizeof(CLObjectReserved);
  data = reserved->privateData;

  return (struct objc_method_description *) class_getInstanceMethod(data->original, aSel);
}

#if 1
-(CLString *) className
{
  CLObjectReserved *reserved;
  CLBridgeData *data;


  reserved = ((void *) self) - sizeof(CLObjectReserved);
  data = reserved->privateData;
  return data->pythonClassName;
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

static int CLObjectBridge_init(CLObjectLink *self, PyObject *args, PyObject *kwds)
{
  if (!PyArg_ParseTuple(args, ":__init__"))
    return -1;

  self->bridgeObject = nil;

  return 0;
}

static void CLObjectBridge_dealloc(CLObjectLink *self)
{
  [self->bridgeObject release];
  return;
}

static PyObject *CLObjectBridge_addObjectToBothSidesOfRelationship(CLObjectLink *self,
								 PyObject *args,
								 PyObject *kwds)
{
  static char *kwlist[] = {"object", "relationship", NULL};
  id object;
  CLString *relationship;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "O&|O&", kwlist,
                                   CLPythonConvert, &object,
                                   CLPythonConvertString, &relationship))
    return NULL;

  [self->bridgeObject addObject:object toBothSidesOfRelationship:relationship];
  Py_RETURN_NONE;
}

static PyMethodDef CLObjectBridge_methods[] = {
  {
    "addObjectToBothSidesOfRelationship",
    (PyCFunction) CLObjectBridge_addObjectToBothSidesOfRelationship,
    METH_VARARGS | METH_KEYWORDS,
    "add passed object to both sides of named relationship of this object",
  },
  {NULL},
};

PyTypeObject CLObjectBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLObject",
  .tp_doc = PyDoc_STR("ClearLake base class"),
  .tp_basicsize = sizeof(CLObjectLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_new = PyType_GenericNew,
  .tp_init = (initproc) CLObjectBridge_init,
  .tp_dealloc = (destructor) CLObjectBridge_dealloc,
  .tp_methods = CLObjectBridge_methods,
};
