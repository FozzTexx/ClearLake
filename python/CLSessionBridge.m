#import "CLSessionBridge.h"
#import "CLObjectBridge.h"

PyTypeObject CLSessionBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLSession",
  .tp_doc = PyDoc_STR("ClearLake object representing a session"),
  .tp_basicsize = sizeof(CLObjectLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_base = &CLObjectBridgeType,
  .tp_new = PyType_GenericNew,
};
