#import "CLDecimalNumberBridge.h"
#import "CLPythonModule.h"
#import <ClearLake/CLDecimalNumber.h>
#import <ClearLake/CLString.h>
#import <ClearLake/CLDecimalMPZ.h>

@implementation CLDecimalNumber (CLPythonExtensions)

-(PyObject *) pythonObject
{
  CLString *decimalString;
  CLDecimalMPZ *val;


  val = value.dval;
  decimalString = [self description];
  if (val->exponent >= 0)
    return PyLong_FromString([decimalString UTF8String], NULL, 10);

  return PyFloat_FromString(CLNativeToPython(decimalString));
}

@end
