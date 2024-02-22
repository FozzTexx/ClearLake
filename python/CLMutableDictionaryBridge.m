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

-(id) objectForKey:(id) aKey
{
  return [CLObjectBridge objectWithPythonObject:
			   PyDict_GetItemString(dictionaryData,
						[[aKey description] UTF8String])];
}

@end
