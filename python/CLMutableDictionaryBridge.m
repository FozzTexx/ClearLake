#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <datetime.h>

#import <ClearLake/CLString.h>
#import "CLMutableDictionaryBridge.h"
#import "CLObjectBridge.h"

@implementation CLMutableDictionary (CLPythonExtensions)

+(id) dictionaryWithPythonObject:(PyObject *) pyList
{
  return [[[CLMutableDictionaryBridge alloc] initWithPythonObject:pyList] autorelease];
}

@end

@implementation CLMutableDictionaryBridge

-(id) initWithPythonObject:(PyObject *) pyObject
{
  [super init];
  Py_INCREF(pyObject);
  dictionaryData = pyObject;
  return self;
}

-(void) dealloc
{
  Py_DECREF(dictionaryData);
  [super dealloc];
  return;
}

-(CLUInteger) count
{
  return PyDict_Size(dictionaryData);
}

-(id) objectForKey:(id) aKey
{
  return [CLObjectBridge objectWithPythonObject:
                           PyDict_GetItemString(dictionaryData,
                                                [[aKey description] UTF8String])];
}

-(CLArray *) allKeys
{
  PyObject *pyKeys;
  id keys;


  pyKeys = PyDict_Keys(dictionaryData);
  keys = [CLObjectBridge objectWithPythonObject:pyKeys];
  Py_DECREF(pyKeys);
  return keys;
}

-(CLArray *) allValues
{
  PyObject *pyValues;
  id values;


  pyValues = PyDict_Values(dictionaryData);
  values = [CLObjectBridge objectWithPythonObject:pyValues];
  Py_DECREF(pyValues);
  return values;
}

-(CLString *) className
{
  return [CLMutableDictionary className];
}

-(void) write:(CLStream *) stream
{
  CLMutableDictionary *mDict = [[CLMutableDictionary alloc] initFromDictionary:self];


  [mDict write:stream];
  [mDict release];
  return;
}

@end
