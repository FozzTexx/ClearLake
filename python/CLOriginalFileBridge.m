#import "CLOriginalFileBridge.h"
#import "CLPythonModule.h"
#import "CLPythonBridge.h"
#import "CLDataBridge.h"
#import <ClearLake/CLOriginalFile.h>
#import <ClearLake/CLData.h>

static int CLOriginalFileBridge_init(CLPyBridgeLink *self, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"data", "filename", "_bridgeObject", NULL};
  PyObject *bridgeCapsule = NULL;
  CLData *data = nil;
  CLString *filename = nil;
  Class nativeClass;


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "|O&O&O!:__init__", kwlist,
                                   CLPyBridgeConvertData, &data,
				   CLPyBridgeConvert, &filename,
				   &PyCapsule_Type, &bridgeCapsule))
    return -1;

  if (!bridgeCapsule) {
    nativeClass = CLClassForPythonObject((PyObject *) self);
    self->bridgeObject = [[nativeClass alloc] initFromData:data table:nil];
    [self->bridgeObject setPythonObject:(PyObject *) self];
    [self->bridgeObject setFilename:filename];
  }
  else
    self->bridgeObject = [(id) PyCapsule_GetPointer(bridgeCapsule, NULL) retain];

  return 0;
}

static void CLOriginalFileBridge_dealloc(CLPyBridgeLink *self)
{
  [self->bridgeObject release];
  return;
}

static PyObject *CLOriginalFileBridge_data(CLPyBridgeLink *self, PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([self->bridgeObject data]);
}

static PyObject *CLOriginalFileBridge_filename(CLPyBridgeLink *self,
					       PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([self->bridgeObject filename]);
}

static int CLOriginalFileBridge_setFilename(CLPyBridgeLink *self, PyObject *value,
					    void *closure)
{
  [self->bridgeObject setFilename:CLPythonToNative(value)];
  return 0;
}

static PyObject *CLOriginalFileBridge_path(CLPyBridgeLink *self,
					       PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([self->bridgeObject path]);
}

static PyGetSetDef CLOriginalFileBridge_getsetters[] = {
  {"data", (getter) CLOriginalFileBridge_data, NULL, "data of the file", NULL},
  {"filename", (getter) CLOriginalFileBridge_filename,
   (setter) CLOriginalFileBridge_setFilename, "suggested filename of the file", NULL},
  {"path", (getter) CLOriginalFileBridge_path, NULL,
   "path to where the data is stored", NULL},
  {NULL},
};

PyTypeObject CLOriginalFileBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLOriginalFile",
  .tp_doc = PyDoc_STR("ClearLake object representing an uploaded file"),
  .tp_basicsize = sizeof(CLPyBridgeLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_base = &CLPyBridgeType,
  .tp_new = PyType_GenericNew,
  .tp_init = (initproc) CLOriginalFileBridge_init,
  .tp_dealloc = (destructor) CLOriginalFileBridge_dealloc,
  .tp_getset = CLOriginalFileBridge_getsetters,
};
