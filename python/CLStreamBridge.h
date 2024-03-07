#ifndef _CLSTREAMBRIDGE_H
#define _CLSTREAMBRIDGE_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import <ClearLake/CLStream.h>

@interface CLStreamBridge:CLStream <CLStream>
{
  PyObject *pythonStream;
}

-(id) initWithPythonStream:(PyObject *) aStream;
-(void) dealloc;

-(int) readByte;
-(void) writeByte:(int) c;
-(int) read:(void *) buffer length:(int) len;
-(int) write:(const void *) buffer length:(int) len;
-(void) close;
-(int) fileno;

@end

extern int CLPyBridgeConvertStream(PyObject *anObj, void *address);

#endif /* _CLSTREAMBRIDGE_H */
