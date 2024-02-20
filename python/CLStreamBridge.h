#ifndef CLPYTHONSTREAM_H
#define CLPYTHONSTREAM_H

#define PY_SSIZE_T_CLEAN
#include <Python.h>

#import <ClearLake/CLStream.h>

@interface CLPythonStream:CLStream <CLStream>
{
  PyObject *pythonStream;
}

-(id) initWithPythonStream:(PyObject *) stream;
-(void) dealloc;

-(int) readByte;
-(void) writeByte:(int) c;
-(int) read:(void *) buffer length:(int) len;
-(int) write:(const void *) buffer length:(int) len;
-(void) close;
-(int) fileno;

@end

extern int CLPythonStreamConvert(PyObject *anObj, void *address);

#endif /* CLPYTHONSTREAM_H */
