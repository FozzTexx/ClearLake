#import "CLStreamBridge.h"

@implementation CLStreamBridge

-(id) initWithPythonStream:(PyObject *) aStream
{
  [super init];
  Py_INCREF(aStream);
  pythonStream = aStream;
  return self;
}

-(void) dealloc
{
  Py_DECREF(pythonStream);
  [super dealloc];
  return;
}

-(int) readByte
{
  unsigned char buf[2];


  if ([self read:buf length:1])
    return buf[0];
  return CLEOF;
}

-(void) writeByte:(int) c
{
  unsigned char buf[2];


  buf[0] = c;
  [self write:buf length:1];
  return;
}

-(int) read:(void *) buffer length:(int) len
{
  PyObject *result;
  Py_ssize_t length;
  char *pyBuf;


  result = PyObject_CallMethod(pythonStream, "read", "I", len);
  PyBytes_AsStringAndSize(result, &pyBuf, &length);
  memcpy(buffer, pyBuf, length);
  Py_DECREF(result);

  return length;
}

-(int) write:(const void *) buffer length:(int) len
{
  long wrote;
  PyObject *bytes = PyBytes_FromStringAndSize(buffer, len);
  PyObject *result = PyObject_CallMethod(pythonStream, "write", "O", bytes);
  Py_DECREF(bytes);

  if (result == NULL)
    return CLEOF;

  wrote = PyLong_AsLong(result);
  Py_DECREF(result);

  return wrote;
}

-(void) close
{
  return;
}

-(int) fileno
{
  return -1;
}

@end

int CLPythonConvertStream(PyObject *anObj, void *address)
{
  *(id *) address = [[[CLStreamBridge alloc] initWithPythonStream:anObj] autorelease];
  return 1;
}
