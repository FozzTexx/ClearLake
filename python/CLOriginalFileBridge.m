#import "CLOriginalFileBridge.h"
#import "CLObjectBridge.h"
#import <ClearLake/CLOriginalFile.h>
#import <ClearLake/CLData.h>

static int CLOriginalFileBridge_init(CLObjectLink *self, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"data", "filename", NULL};
  CLData *data;
  CLString *filename = nil;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "O&|O&", kwlist,
                                   CLPythonConvert, &data,
				   CLPythonConvert, &filename))
    return -1;

  self->bridgeObject = [[CLOriginalFile alloc] initFromData:data table:nil];
  [self->bridgeObject setFilename:filename];

  return 0;
}

static void CLOriginalFileBridge_dealloc(CLObjectLink *self)
{
  [self->bridgeObject release];
  return;
}

static PyObject *CLOriginalFileBridge_data(CLObjectLink *self, PyObject *Py_UNUSED(ignored))
{
  return [[self->bridgeObject data] pythonObject];
}

static PyObject *CLOriginalFileBridge_filename(CLObjectLink *self,
					       PyObject *Py_UNUSED(ignored))
{
  return [[self->bridgeObject filename] pythonObject];
}

static PyObject *CLOriginalFileBridge_path(CLObjectLink *self,
					       PyObject *Py_UNUSED(ignored))
{
  return [[self->bridgeObject path] pythonObject];
}

static PyGetSetDef CLOriginalFileBridge_getsetters[] = {
  {"data", (getter) CLOriginalFileBridge_data, NULL, "data of the file", NULL},
  {"filename", (getter) CLOriginalFileBridge_filename, NULL,
   "suggested filename of the file", NULL},
  {"path", (getter) CLOriginalFileBridge_path, NULL,
   "path to where the data is stored", NULL},
  {NULL},
};

PyTypeObject CLOriginalFileBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLOriginalFile",
  .tp_doc = PyDoc_STR("ClearLake object representing an uploaded file"),
  .tp_basicsize = sizeof(CLObjectLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_base = &CLObjectBridgeType,
  .tp_new = PyType_GenericNew,
  .tp_init = (initproc) CLOriginalFileBridge_init,
  .tp_dealloc = (destructor) CLOriginalFileBridge_dealloc,
  .tp_getset = CLOriginalFileBridge_getsetters,
};
