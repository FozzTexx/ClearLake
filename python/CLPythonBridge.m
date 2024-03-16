#import "CLPythonBridge.h"
#import "CLPythonModule.h"
#import "CLStringBridge.h"
#import "CLDataBridge.h"
#import "CLArrayBridge.h"
#import "CLMutableArrayBridge.h"
#import "CLMutableDictionaryBridge.h"

#include <datetime.h>

#import <ClearLake/CLStream.h>
#import <ClearLake/CLInvocation.h>
#import <ClearLake/CLMethodSignature.h>
#import <ClearLake/CLNumber.h>
#import <ClearLake/CLGenericRecord.h>
#import <ClearLake/CLClassConstants.h>
#import <ClearLake/CLMutableData.h>

static const char * _bridgeSubclassMethods[] = {
  "initWithPythonObject:",
  "dealloc",
  "setObject:forPythonAttribute:",
  "objectValueForKey:found:",
  "setObjectValue:forKey:found:",
  "pythonizeSelector:",
  "pythonRespondsTo:",
  "read:",
  "write:",
  "respondsTo:",
  "forwardInvocation:",
  NULL,
};

static void *_dynamicSuperCall(id receiver, SEL sel, ...)
{
  va_list ap;
  CLInvocation *invoc = nil;
  void *ret = NULL;
  Class superClass;
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif


  superClass = class_getSuperclass([receiver class]);
  while ([superClass isKindOfClass:[CLPythonBridge class]])
    superClass = class_getSuperclass(superClass);

  va_start(ap, sel);
  invoc = CLCreateInvocation(receiver, sel, ap);
  va_end(ap);
  [invoc invokeWithClass:superClass];
  [invoc getReturnValue:&ret];
  [invoc release];
  return ret;
}

@implementation CLPythonBridge

+(Class) createBridgeClassFromPythonClass:(PyTypeObject *) pyClass
{
  Class aClass, bridgeClass;
  CLMethodInfo *methods, *aMethod;
  CLUInteger idx, idx2, count;
  CLString *className, *moduleName;
  PyObject *pyModule = NULL;


  aClass = CLNativeSuperclassForPythonClass((PyObject *) pyClass);
  if (!aClass)
    aClass = self;

  if (pyClass->tp_dict)
    pyModule = PyDict_GetItemString(pyClass->tp_dict, "__module__");

  moduleName = [CLString stringWithUTF8String:PyUnicode_AsUTF8(pyModule)];
  className = [CLString stringWithUTF8String:pyClass->tp_name];
#if 0
  fprintf(stderr, "Creating class %s from %s.%s\n", [className UTF8String],
	  [moduleName UTF8String], [className UTF8String]);
#endif

  if (![moduleName isEqualToString:@"__main__"]) {
    PyObject *mainModule;


    mainModule = PyImport_AddModule("__main__");
    if (!mainModule)
      [self error:@"Unable to find Python module __main__"];

    if (PyObject_HasAttrString(mainModule, [className UTF8String]))
      className = [CLString stringWithFormat:@"%@.%@", moduleName, className];
  }

  bridgeClass = objc_allocateClassPair(aClass, [className UTF8String], 0);
  if (!bridgeClass)
    [self error:@"Failed to allocate class %@", className];

  if (aClass != self) {
    methods = CLGetMethods(self, &count);
    for (idx2 = 0; _bridgeSubclassMethods[idx2]; idx2++) {
      for (idx = 0; idx < count; idx++) {
	aMethod = &methods[idx];
	if (!strcmp(_bridgeSubclassMethods[idx2], aMethod->name)) {
	  class_addMethod(bridgeClass, sel_getUid(_bridgeSubclassMethods[idx2]),
			  aMethod->imp, aMethod->methodTypes);
	  break;
	}
      }
    }
  }

  objc_registerClassPair(bridgeClass);

  return bridgeClass;
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
    anObject = [CLArray arrayWithPythonObject:pyObject];
  else if (PyList_Check(pyObject))
    anObject = [CLMutableArray arrayWithPythonObject:pyObject];
  else if (PyBytes_Check(pyObject))
    anObject = [CLData dataFromPythonObject:pyObject];
  else if (PyByteArray_Check(pyObject))
    anObject = [CLMutableData dataFromPythonObject:pyObject];
  else if (PyDateTime_Check(pyObject))
    [self error:@"Conversion to CLDatetime not implemented"];
  else if (PyDict_Check(pyObject))
    anObject = [CLMutableDictionary dictionaryWithPythonObject:pyObject];
  else if (PySet_Check(pyObject))
    [self error:@"There's no set class in ClearLake!"];
  else if (CLNativeSuperclassForPythonClass(pyObject))
    anObject = ((CLPyBridgeLink *) pyObject)->bridgeObject;
  else {
    Class aClass = CLClassForPythonObject(pyObject);


    anObject = [[[aClass alloc] initWithPythonObject:pyObject] autorelease];
  }

  if (!anObject)
    [self error:@"Where did the object go?"];

  return anObject;
}

-(id) init
{
  CLString *className;
  PyObject *pyClass, *pyObject;


  className = [self className];
  pyClass = (PyObject *) CLPythonClassFromString(className);
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
  if (!pyObject)
    [self error:@"init with what?"];

  _dynamicSuperCall(self, @selector(init));
  [self setPythonObject:pyObject];

  return self;
}

-(void) dealloc
{
  CLObjectReserved *reserved;
  CLBridgeData *data;


  reserved = ((void *) self) - sizeof(CLObjectReserved);
  data = reserved->privateData;
  if (data) {
    if (data->pyObject)
      Py_DECREF(data->pyObject);
    reserved->privateData = data->originalPrivate;
    free(data);
  }
  _dynamicSuperCall(self, @selector(dealloc));

  /* Just here to make the compiler warning go away */
  if (0)
    [super dealloc];

  return;
}

-(BOOL) pythonRespondsTo:(CLString *) aMethod
{
  PyObject *attr, *pyBinding, *pyObject;
  BOOL hasMethod = NO;


  pyBinding = CLNativeToPython(aMethod);
  if ((pyObject = CLNativeToPython(self))) {
    attr = PyObject_GetAttr(pyObject, pyBinding);
    if (!attr)
      PyErr_Clear();
    else if (PyCallable_Check(attr))
      hasMethod = YES;
    Py_XDECREF(attr);
  }
  Py_XDECREF(pyObject);
  Py_XDECREF(pyBinding);

  return hasMethod;
}

-(id) objectValueForKey:(CLString *) aKey found:(BOOL *) found
{
  CLObjectReserved *reserved;
  CLBridgeData *data;
  id anObject = nil;
  PyObject *result, *attr;
  PyObject *pyBinding;


  *found = NO;
  if (![self pythonRespondsTo:aKey])
    anObject = _dynamicSuperCall(self, @selector(objectValueForKey:found:),
				 aKey, found);

  reserved = ((void *) self) - sizeof(CLObjectReserved);
  data = reserved->privateData;

  if (!*found && data && data->pyObject) {
    pyBinding = CLNativeToPython(aKey);
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

      Py_DECREF(attr);
      Py_DECREF(pyBinding);

      anObject = CLPythonToNative(result);

      if (result)
        Py_DECREF(result);
    }

#if 0
    fprintf(stderr, "0x%lx %s getting \"%s\": %s\n", (unsigned long) self,
	    [[self className] UTF8String],
	    [aKey UTF8String], [[anObject description] UTF8String]);
#endif
  }

  return anObject;
}

-(void) setObject:(id) anObject forPythonAttribute:(CLString *) anAttr
{
  CLObjectReserved *reserved;
  CLBridgeData *data;
  PyObject *value;


#if 0
  fprintf(stderr, "0x%lx %s setting Python attribute \"%s\" to \"%s\"\n",
	  (unsigned long) self,
	  [[self className] UTF8String],
	  [anAttr UTF8String], [[anObject description] UTF8String]);
#endif

  value = CLNativeToPython(anObject);

  reserved = ((void *) self) - sizeof(CLObjectReserved);
  data = reserved->privateData;
  if (PyObject_SetAttrString(data->pyObject, [anAttr UTF8String], value) < 0) {
    PyErr_Print();
    [self error:@"Unable to set attribute \"%@\" of python object", anAttr];
  }

  Py_DECREF(value);
  return;
}

-(void) setObjectValue:(id) anObject forKey:(id) aKey found:(BOOL *) found
{
  _dynamicSuperCall(self, @selector(setObjectValue:forKey:found:), anObject, aKey, found);
  if (!*found) {
    *found = YES;
    [self setObject:anObject forPythonAttribute:aKey];
  }

#if 0
  fprintf(stderr, "0x%lx %s setting \"%s\" to \"%s\"\n", (unsigned long) self,
	  [[self className] UTF8String],
	  [aKey UTF8String], [[anObject description] UTF8String]);
#endif

  return;
}

-(CLString *) pythonizeSelector:(SEL) aSel
{
  CLString *aString;


  aString = CLStringFromSelector(aSel);
  if ([aString hasSuffix:@":"])
    aString = [aString substringToIndex:[aString length] - 1];
  return aString;
}

-(id) read:(CLStream *) stream
{
  id anObject;
  BOOL found;


  self = _dynamicSuperCall(self, @selector(read:), stream);
  [stream readType:@"@" data:&anObject];
  if (anObject && [self pythonRespondsTo:@"__setstate__"])
    [self setObjectValue:anObject forKey:@"__setstate__" found:&found];
  else if ([anObject isKindOfClass:CLDictionaryClass]) {
    PyObject *myDict, *pyObject;


    pyObject = CLNativeToPython(self);
    myDict = PyObject_GetAttrString(pyObject, "__dict__");
    if (PyDict_Check(myDict)) {
      if (PyDict_Update(myDict, CLNativeToPython(anObject)) != 0) {
	PyErr_Print();
        [self error:@"Unable to read"];
      }
    }
    Py_DECREF(myDict);
    Py_XDECREF(pyObject);
  }

  return self;
}

-(void) write:(CLStream *) stream
{
  id anObject;


  _dynamicSuperCall(self, @selector(write:), stream);
  anObject = [self objectValueForBinding:@"__getstate__"];

  if ([anObject isKindOfClass:[CLDictionary class]]) {
    CLUInteger idx, count;
    CLArray *keys;
    CLString *aKey;


    anObject = [anObject mutableCopy];
    keys = [anObject allKeys];
    for (idx = 0, count = [keys count]; idx < count; idx++) {
      aKey = [keys objectAtIndex:idx];
      if ([self hasFieldNamed:aKey])
	[anObject removeObjectForKey:aKey];
    }

    if (![anObject count])
      anObject = nil;
  }

  [stream writeType:@"@" data:&anObject];
  return;
}

-(BOOL) respondsTo:(SEL) aSel
{
  if (class_getInstanceMethod(class_getSuperclass(self->isa), aSel)
      || [self pythonRespondsTo:[self pythonizeSelector:aSel]])
    return YES;

  return NO;
}

-(void) forwardInvocation:(CLInvocation *) anInvocation
{
  CLObjectReserved *reserved;
  CLBridgeData *data;
  CLMethodSignature *sig;
  CLString *aBinding;
  PyObject *attr, *result, *py_tuple = NULL;
  CLUInteger idx, count;
  id arg, anObject = nil;


  if ([self pythonRespondsTo:[self pythonizeSelector:[anInvocation selector]]]) {
    reserved = ((void *) self) - sizeof(CLObjectReserved);
    data = reserved->privateData;

    sig = [anInvocation methodSignature];
    aBinding = [self pythonizeSelector:[anInvocation selector]];
    attr = PyObject_GetAttrString(data->pyObject, [aBinding UTF8String]);

    count = [sig numberOfArguments] - 2;
    if (count) {
      py_tuple = PyTuple_New(count);
      for (idx = 0; idx < count; idx++) {
	arg = [anInvocation objectValueForArgumentAtIndex:idx + 2];
	result = CLNativeToPython(arg);
	if (PyTuple_SetItem(py_tuple, idx, result) != 0) {
	  PyErr_Print();
	  [self error:@"Unable to forward %@", aBinding];
	}
	Py_XDECREF(result);
      }
    }

    result = PyObject_CallObject(attr, py_tuple);
    if (result) {
      anObject = CLPythonToNative(result);
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

  // set/get will be handled by super by calling
  // setObjectValue:forKey:found/objectValueForKey:found:

  _dynamicSuperCall(self, @selector(forwardInvocation:), anInvocation);

  return;
}

-(void) willChange
{
  [super willChange];
  return;
}

@end

@implementation CLObject (CLPythonBridgeExtensions)

-(PyObject *) pythonObject
{
  CLObjectReserved *reserved;
  CLBridgeData *data;
  PyObject *kwargs = NULL;


  reserved = ((void *) self) - sizeof(CLObjectReserved);
  data = reserved->privateData;
  if (!data || !data->pyObject) {
    CLPyBridgeLink *obj;
    PyTypeObject *pyClass;
    PyObject *args;


    if (!data) {
      data = calloc(1, sizeof(CLBridgeData));
      reserved->privateData = data;
    }

    pyClass = CLPythonClassFromString([self className]);
    if (!pyClass) {
      pyClass = CLPythonBridgeTypeForClass([self class]);
      if (!pyClass)
	pyClass = &CLPyBridgeType;
    }

    if (CLIsBridgeClass(pyClass)) {
      kwargs = PyDict_New();
      PyDict_SetItemString(kwargs, "_bridgeObject", PyCapsule_New(self, NULL, NULL));
    }

    args = PyTuple_New(0);
    obj = (CLPyBridgeLink *) PyObject_Call((PyObject *) pyClass, args, kwargs);
    if (!obj) {
      PyErr_Print();
      [self error:@"Unable to create Python link"];
    }
    [self setPythonObject:(PyObject *) obj];
    // setPythonObject: incremented the new reference we created, decrement it
    Py_DECREF(obj);

    Py_XDECREF(args);
    Py_XDECREF(kwargs);

    // FIXME - could leak data & pyObject
  }

  Py_INCREF(data->pyObject);
  return data->pyObject;
}

-(void) setPythonObject:(PyObject *) pyObject
{
  CLObjectReserved *reserved;
  CLBridgeData *data;


  reserved = ((void *) self) - sizeof(CLObjectReserved);
  data = reserved->privateData;
  if (!data) {
    data = calloc(1, sizeof(CLBridgeData));
    reserved->privateData = data;
  }

  Py_INCREF(pyObject);
  if (data->pyObject)
    Py_DECREF(data->pyObject);
  data->pyObject = pyObject;

  // FIXME - could leak data & pyObject

  return;
}

@end

int CLPyBridgeConvert(PyObject *anObj, void *address)
{
  *(id *) address = CLPythonToNative(anObj);
  return 1;
}

static int CLPyBridge_init(CLPyBridgeLink *pySelf, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"_bridgeObject", NULL};
  PyObject *bridgeCapsule = NULL;
  Class nativeClass;
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "|O!:__init__", kwlist,
				   &PyCapsule_Type, &bridgeCapsule))
    return -1;

  if (!bridgeCapsule) {
    // FIXME - allow subclasses to call init
    nativeClass = CLClassForPythonObject((PyObject *) pySelf);
    pySelf->bridgeObject = [[nativeClass alloc] initWithPythonObject:(PyObject *) pySelf];
  }
  else
    pySelf->bridgeObject = [(id) PyCapsule_GetPointer(bridgeCapsule, NULL) retain];

  return 0;
}

static void CLPyBridge_dealloc(CLPyBridgeLink *pySelf)
{
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif
  [pySelf->bridgeObject release];
  return;
}

static PyObject *CLPyBridge_addObjectToBothSidesOfRelationship(CLPyBridgeLink *pySelf,
								 PyObject *args,
								 PyObject *kwds)
{
  static char *kwlist[] = {"object", "relationship", NULL};
  id object;
  CLString *relationship;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "O&O&", kwlist,
                                   CLPyBridgeConvert, &object,
                                   CLPyBridgeConvertString, &relationship))
    return NULL;

  [pySelf->bridgeObject addObject:object toBothSidesOfRelationship:relationship];
  Py_RETURN_NONE;
}

static PyMethodDef CLPyBridge_methods[] = {
  {
    "addObjectToBothSidesOfRelationship",
    (PyCFunction) CLPyBridge_addObjectToBothSidesOfRelationship,
    METH_VARARGS | METH_KEYWORDS,
    "add passed object to both sides of named relationship of this object",
  },
  {NULL},
};

PyTypeObject CLPyBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLObject",
  .tp_doc = PyDoc_STR("ClearLake base class"),
  .tp_basicsize = sizeof(CLPyBridgeLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_new = PyType_GenericNew,
  .tp_init = (initproc) CLPyBridge_init,
  .tp_dealloc = (destructor) CLPyBridge_dealloc,
  .tp_methods = CLPyBridge_methods,
};
