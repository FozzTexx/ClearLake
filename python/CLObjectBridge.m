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
#import "CLDataBridge.h"

#import <ClearLake/CLInvocation.h>
#import <ClearLake/CLNumber.h>
#import <ClearLake/CLMutableString.h>
#import <ClearLake/CLMethodSignature.h>
#import <ClearLake/CLGenericRecord.h>
#import <ClearLake/CLStream.h>

Class CLObjectBridgeClass;

static void CLInitBridgeClassConstants()
{
  CLObjectBridgeClass = [CLObjectBridge class];
  return;
}

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

+(void) initialize
{
  CLInitBridgeClassConstants();
  return;
}

+(id) allocAsClass:(Class) aClass
{
  CLObjectReserved *reserved;
  CLBridgeData *data;
  CLString *className;
  CLRange aRange;
  Class nativeClass;
  id anObject;


  className = [CLString stringWithUTF8String:((CLClassDef *) aClass)->name];
  aRange = [className rangeOfString:@":"];
  if (!aRange.length)
    [self error:@"Unrecognizable class: %@", className];
  className = [className substringToIndex:aRange.location];
  nativeClass = CLClassFromString(className);

  if (((CLClassDef *) nativeClass)->class_pointer
      == ((CLClassDef *) CLObjectBridgeClass)->class_pointer)
    anObject = [super alloc];
  else
    anObject = [nativeClass alloc];

  reserved = ((void *) anObject) - sizeof(CLObjectReserved);
  data = calloc(1, sizeof(CLBridgeData));
  data->originalPrivate = reserved->privateData;
  reserved->privateData = data;
  data->nativeClass = nativeClass;
  ((CLObjectBridge *) anObject)->isa = aClass;

  return anObject;
}

+(id) alloc
{
  return [self allocAsClass:self];
}

+(id) objectWithPythonObject:(PyObject *) pyObject
{
  id anObject = nil;


  PyDateTime_IMPORT;

  if (!pyObject || pyObject == Py_None)
    return nil;

  if (PyLong_Check(pyObject))
    anObject = [CLNumber numberWithLongLong:PyLong_AsLongLong(pyObject)];
  else if (PyFloat_Check(pyObject))
    anObject = [CLNumber numberWithDouble:PyFloat_AsDouble(pyObject)];
  else if (PyUnicode_Check(pyObject))
    anObject = [CLString stringFromPythonObject:pyObject];
  else if (PyTuple_Check(pyObject))
    [self error:@"Conversion to CLArray not implemented"];
  else if (PyList_Check(pyObject))
    anObject = [CLMutableArray arrayWithPythonObject:pyObject];
  else if (PyBytes_Check(pyObject))
    anObject = [CLData dataFromPythonObject:pyObject];
  else if (PyByteArray_Check(pyObject))
    [self error:@"Conversion to CLMutableData not implemented"];
  else if (PyDateTime_Check(pyObject))
    [self error:@"Conversion to CLDatetime not implemented"];
  else if (PyDict_Check(pyObject))
    anObject = [CLMutableDictionary dictionaryWithPythonObject:pyObject];
  else if (PySet_Check(pyObject))
    [self error:@"There's no set class in ClearLake!"];
  else if (CLNativeSuperclassForPythonClass(pyObject))
    anObject = ((CLObjectLink *) pyObject)->bridgeObject;
  else {
    CLString *pyClassName;
    Class bridgeClass;


    pyClassName = [CLString stringWithUTF8String:pyObject->ob_type->tp_name];
    bridgeClass = CLClassFromString(pyClassName);
    anObject = [[[self allocAsClass:bridgeClass] initWithPythonObject:pyObject] autorelease];
  }

  if (!anObject)
    [self error:@"Where did the object go?"];

  return anObject;
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
  if (!pyObject)
    [self error:@"Failed to create instance: %@", className];

  [self initWithPythonObject:pyObject];
  Py_DECREF(pyObject);

  return self;
}

-(id) initWithPythonObject:(PyObject *) pyObject
{
  CLObjectReserved *reserved;
  CLBridgeData *data;
  Class current;
  CLString *className;
  CLRange aRange;


  if (!pyObject)
    [self error:@"init with what?"];

  className = [CLString stringWithUTF8String:((CLClassDef *) [self class])->name];
  aRange = [className rangeOfString:@":"];
  if (!aRange.length)
    [self error:@"Unrecognizable class: %@", className];

  reserved = ((void *) self) - sizeof(CLObjectReserved);
  data = reserved->privateData;

  [self setPythonObject:pyObject];

  if (((CLClassDef *) data->nativeClass)->class_pointer
      == ((CLClassDef *) CLObjectBridgeClass)->class_pointer)
    [super init];
  else {
    current = self->isa;
    self->isa = data->nativeClass;
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
  [data->pythonClassName release];
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

-(void) setPythonObject:(PyObject *) pyObject
{
  CLObjectReserved *reserved;
  CLBridgeData *data;
  PyTypeObject *type;


  reserved = ((void *) self) - sizeof(CLObjectReserved);
  data = reserved->privateData;

  Py_INCREF(pyObject);
  if (data->pyObject)
    Py_DECREF(data->pyObject);
  data->pyObject = pyObject;
  type = Py_TYPE(pyObject);
  [data->pythonClassName release];
  data->pythonClassName = [[CLString alloc] initWithUTF8String:type->tp_name];
  return;
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

  if (((CLClassDef *) data->nativeClass)->class_pointer
      != ((CLClassDef *) CLObjectBridgeClass)->class_pointer) {
    current = self->isa;
    self->isa = data->nativeClass;
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

-(void) setObject:anObject forPythonAttribute:(CLString *) anAttr
{
  CLObjectReserved *reserved;
  CLBridgeData *data;
  PyObject *value;


  [self willChange];

  if (anObject)
    value = [anObject pythonObject];
  else {
    value = Py_None;
    Py_INCREF(value);
  }

  reserved = ((void *) self) - sizeof(CLObjectReserved);
  data = reserved->privateData;
  if (PyObject_SetAttrString(data->pyObject, [anAttr UTF8String], value) < 0)
    [self error:@"Unable to set attribute of python object"];

  Py_DECREF(value);
  return;
}

/* This is a lot like setObjectValue:forBinding: except that it avoids
   the willChange */
-(void) setPrimitiveValue:(id) anObject forKey:(CLString *) aKey
{
  CLObjectReserved *reserved;
  CLBridgeData *data;
  BOOL found = NO;
  Class current;
  SEL sel;
  int aType;


  reserved = ((void *) self) - sizeof(CLObjectReserved);
  data = reserved->privateData;
  current = self->isa;
  self->isa = data->nativeClass;
  sel = sel_getUid([aKey UTF8String]);
  if ([self pointerForIvar:[aKey UTF8String] type:&aType] || [self respondsTo:sel]) {
    /* Yes this looks like it could go into an infinite loop but
       this call is to the swizzled class */
    [self setPrimitiveValue:anObject forKey:aKey];
    found = YES;
  }
  self->isa = current;

  if (!found)
    [self setObject:anObject forPythonAttribute:aKey];

  return;
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
    self->isa = data->nativeClass;
    if ([self pointerForIvar:[aBinding UTF8String] type:&aType] || [self respondsTo:sel]) {
      /* Yes this looks like it could go into an infinite loop but
	 this call is to the swizzled class */
      [self setObjectValue:anObject forBinding:aBinding];
      found = YES;
    }
    self->isa = current;

    if (!found) {
      [self willChange];
      [self setObject:anObject forPythonAttribute:aBinding];
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

  if (class_getInstanceMethod(data->nativeClass, aSel)
      || [self pythonRespondsTo:[self pythonizeSelector:aSel]])
    return YES;

  return NO;
}

+(void) forwardInvocation:(CLInvocation *) anInvocation
{
  CLString *className;
  CLRange aRange;
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
  if (class_getInstanceMethod(data->nativeClass, [anInvocation selector])) {
    current = self->isa;
    self->isa = data->nativeClass;
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

  return method_getImplementation(class_getInstanceMethod(data->nativeClass, aSel));
}

-(struct objc_method_description *) descriptionForMethod:(SEL) aSel
{
  CLObjectReserved *reserved;
  CLBridgeData *data;


  reserved = (void *) self - sizeof(CLObjectReserved);
  data = reserved->privateData;

  return (struct objc_method_description *) class_getInstanceMethod(data->nativeClass, aSel);
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

-(void) willSaveToDatabase
{
  CLObjectReserved *reserved;
  CLBridgeData *data;
  Class current;


  reserved = (void *) self - sizeof(CLObjectReserved);
  data = reserved->privateData;

  current = self->isa;
  self->isa = data->nativeClass;
  [self willSaveToDatabase];
  self->isa = current;
  return;
}

@end

int CLPythonConvert(PyObject *anObj, void *address)
{
  *(id *) address = [CLObjectBridge objectWithPythonObject:anObj];
  return 1;
}

static int CLObjectBridge_init(CLObjectLink *self, PyObject *args, PyObject *kwds)
{
  Class nativeClass;


  if (!PyArg_ParseTuple(args, ":__init__"))
    return -1;

  nativeClass = CLClassForPythonObject((PyObject *) self);
  self->bridgeObject = [[nativeClass alloc] initWithPythonObject:self];

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


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "O&O&", kwlist,
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
