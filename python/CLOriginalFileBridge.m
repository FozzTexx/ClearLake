#import "CLOriginalFileBridge.h"
#import "CLPythonModule.h"
#import "CLPythonBridge.h"
#import "CLDataBridge.h"
#import <ClearLake/CLOriginalFile.h>
#import <ClearLake/CLData.h>

static int CLOriginalFileBridge_init(CLPyBridgeLink *pySelf, PyObject *args, PyObject *kwds)
{
  static char *kwlist[] = {"data", "filename", "_bridgeObject", NULL};
  PyObject *bridgeCapsule = NULL;
  CLData *data = nil;
  CLString *filename = nil;
  Class nativeClass;
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif


  if (!PyArg_ParseTupleAndKeywords(args, kwds, "|O&O&O!:__init__", kwlist,
                                   CLPyBridgeConvertData, &data,
				   CLPyBridgeConvert, &filename,
				   &PyCapsule_Type, &bridgeCapsule))
    return -1;

  if (!bridgeCapsule) {
    nativeClass = CLClassForPythonObject((PyObject *) pySelf);
    pySelf->bridgeObject = [[nativeClass alloc] initFromData:data table:nil];
    [pySelf->bridgeObject setPythonObject:(PyObject *) pySelf];
    [pySelf->bridgeObject setFilename:filename];
  }
  else
    pySelf->bridgeObject = [(id) PyCapsule_GetPointer(bridgeCapsule, NULL) retain];

  return 0;
}

static void CLOriginalFileBridge_dealloc(CLPyBridgeLink *pySelf)
{
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif
  [pySelf->bridgeObject release];
  return;
}

static PyObject *CLOriginalFileBridge_download(CLPyBridgeLink *pySelf, PyObject *arg)
{
  [pySelf->bridgeObject download:CLPythonToNative(arg)];
  Py_RETURN_NONE;
}

static PyObject *CLOriginalFileBridge_data(CLPyBridgeLink *pySelf, PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([pySelf->bridgeObject data]);
}

static PyObject *CLOriginalFileBridge_filename(CLPyBridgeLink *pySelf,
					       PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([pySelf->bridgeObject filename]);
}

static int CLOriginalFileBridge_setFilename(CLPyBridgeLink *pySelf, PyObject *value,
					    void *closure)
{
  [pySelf->bridgeObject setFilename:CLPythonToNative(value)];
  return 0;
}

static PyObject *CLOriginalFileBridge_path(CLPyBridgeLink *pySelf,
					       PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([pySelf->bridgeObject path]);
}

static PyGetSetDef CLOriginalFileBridge_getsetters[] = {
  {"data", (getter) CLOriginalFileBridge_data, NULL, "data of the file", NULL},
  {"filename", (getter) CLOriginalFileBridge_filename,
   (setter) CLOriginalFileBridge_setFilename, "suggested filename of the file", NULL},
  {"path", (getter) CLOriginalFileBridge_path, NULL,
   "path to where the data is stored", NULL},
  {NULL},
};

static PyMethodDef CLOriginalFileBridge_methods[] = {
  {"download", (PyCFunction) CLOriginalFileBridge_download, METH_O,
    "send the contents of the file to the browser"},
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
  .tp_methods = CLOriginalFileBridge_methods,
  .tp_getset = CLOriginalFileBridge_getsetters,
};
