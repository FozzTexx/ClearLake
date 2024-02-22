#import "CLFormBridge.h"
#import "CLObjectBridge.h"
#import <ClearLake/CLForm.h>

@implementation CLForm (CLPythonExtensions)

-(PyObject *) pythonObject
{
  CLObjectLink *obj;


  obj = (CLObjectLink *) CLFormBridgeType.tp_new(&CLFormBridgeType, PyTuple_New(0), NULL);
  obj->bridgeObject = self;
  return (PyObject *) obj;
}

@end

int CLFormBridge_init(CLObjectLink *self, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"string", "value", "selected", NULL};
  CLString *string = nil;
  id value = nil;
  int selected = NO;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "O&O&|p", kwlist,
				   CLPythonConvert, &string,
				   CLPythonConvert, &value,
				   &selected))
    return -1;

  self->bridgeObject = [[CLForm alloc] init];

  return 0;
}

void CLFormBridge_dealloc(CLObjectLink *self)
{
  [self->bridgeObject release];
  return;
}

PyTypeObject CLFormBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLForm",
  .tp_doc = PyDoc_STR("ClearLake object representing a form"),
  .tp_basicsize = sizeof(CLObjectLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_new = PyType_GenericNew,
  .tp_init = (initproc) CLFormBridge_init,
  .tp_dealloc = (destructor) CLFormBridge_dealloc,
};

