#import "CLAccountBridge.h"
#import "CLPythonBridge.h"
#import "CLPythonModule.h"
#import <ClearLake/CLAccount.h>

static PyObject *CLAccountBridge_email(CLPyBridgeLink *self, PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([self->bridgeObject email]);
}

static int CLAccountBridge_setEmail(CLPyBridgeLink *self, PyObject *value, void *closure)
{
  [self->bridgeObject setEmail:CLPythonToNative(value)];
  return 0;
}

static PyObject *CLAccountBridge_name(CLPyBridgeLink *self, PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([self->bridgeObject name]);
}

static int CLAccountBridge_setName(CLPyBridgeLink *self, PyObject *value, void *closure)
{
  [self->bridgeObject setName:CLPythonToNative(value)];
  return 0;
}

static PyObject *CLAccountBridge_password(CLPyBridgeLink *self, PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([self->bridgeObject password]);
}

static int CLAccountBridge_setPassword(CLPyBridgeLink *self, PyObject *value, void *closure)
{
  [self->bridgeObject setPassword:CLPythonToNative(value)];
  return 0;
}

static PyObject *CLAccountBridge_flags(CLPyBridgeLink *self, PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([self->bridgeObject flags]);
}

static int CLAccountBridge_setFlags(CLPyBridgeLink *self, PyObject *value, void *closure)
{
  [self->bridgeObject setFlags:CLPythonToNative(value)];
  return 0;
}

static PyObject *CLAccountBridge_created(CLPyBridgeLink *self, PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([self->bridgeObject created]);
}

static int CLAccountBridge_setCreated(CLPyBridgeLink *self, PyObject *value, void *closure)
{
  [self->bridgeObject setCreated:CLPythonToNative(value)];
  return 0;
}

static PyObject *CLAccountBridge_ipAddress(CLPyBridgeLink *self, PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([self->bridgeObject ipAddress]);
}

static int CLAccountBridge_setIpAddress(CLPyBridgeLink *self, PyObject *value, void *closure)
{
  [self->bridgeObject setIpAddress:CLPythonToNative(value)];
  return 0;
}

static PyObject *CLAccountBridge_lastSeen(CLPyBridgeLink *self, PyObject *Py_UNUSED(ignored))
{
  return CLNativeToPython([self->bridgeObject lastSeen]);
}

static int CLAccountBridge_setLastSeen(CLPyBridgeLink *self, PyObject *value, void *closure)
{
  [self->bridgeObject setLastSeen:CLPythonToNative(value)];
  return 0;
}

static PyGetSetDef CLAccountBridge_getsetters[] = {
  {"email", (getter) CLAccountBridge_email, (setter) CLAccountBridge_setEmail,
   "get the email address of the acccount", "set the email address for the account"},
  {"name", (getter) CLAccountBridge_name, (setter) CLAccountBridge_setName,
   "get the name of the acccount", "set the name for the account"},
  {"password", (getter) CLAccountBridge_password, (setter) CLAccountBridge_setPassword,
   "get the encrypted password", "set the encrypted password"},
  {"flags", (getter) CLAccountBridge_flags, (setter) CLAccountBridge_setFlags,
   "get the flags of the acccount", "set the flags for the account"},
  {"created", (getter) CLAccountBridge_created, (setter) CLAccountBridge_setCreated,
   "get when the acccount was created", "set when the account was created"},
  {"ipAddress", (getter) CLAccountBridge_ipAddress, (setter) CLAccountBridge_setIpAddress,
   "get the most recent IP address", "set the most recent IP address"},
  {"lastSeen", (getter) CLAccountBridge_lastSeen, (setter) CLAccountBridge_setLastSeen,
   "get when the acccount last logged in", "set when the account last logged in"},
  {NULL},
};

PyTypeObject CLAccountBridgeType = {
  .ob_base = PyVarObject_HEAD_INIT(NULL, 0)
  .tp_name = "ClearLake.CLAccount",
  .tp_doc = PyDoc_STR("ClearLake object representing an account"),
  .tp_basicsize = sizeof(CLPyBridgeLink),
  .tp_itemsize = 0,
  .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
  .tp_base = &CLPyBridgeType,
  .tp_new = PyType_GenericNew,
  .tp_getset = CLAccountBridge_getsetters,
};
