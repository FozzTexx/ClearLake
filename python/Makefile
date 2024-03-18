PYTHON_VERSION=$(shell python3 -c "import sys; print(f'cpython-{sys.version_info.major}{sys.version_info.minor}')")
PLATFORM=$(shell python3 -c "import sysconfig; print(sysconfig.get_platform())")
ABI_TAG=$(shell python3 -c "import sysconfig; print(sysconfig.get_config_var('SOABI'))")
BUILD_DIR=build

MODULE_LIB=$(BUILD_DIR)/lib.$(PLATFORM)-$(PYTHON_VERSION)/ClearLake.$(ABI_TAG).so

CLASSES_M=CLPageBridge.m CLStreamBridge.m CLStringBridge.m		\
          CLOptionBridge.m CLArrayBridge.m CLMutableArrayBridge.m	\
          CLMutableDictionaryBridge.m CLNumberBridge.m CLDataBridge.m	\
          CLFormBridge.m CLControlBridge.m CLOriginalFileBridge.m	\
          CLManagerBridge.m CLSessionBridge.m CLPythonBridge.m		\
          CLAccountBridge.m CLInputBridge.m CLDecimalNumberBridge.m	\
          CLGenericRecordBridge.m CLElementBridge.m
CLASSES_H=$(CLASSES_M:.m=.h)

$(MODULE_LIB): CLPythonModule.m $(CLASSES_M) $(CLASSES_H) setup.py pyproject.toml
	python3 setup.py clean --all
	python3 -m pip install .
	python3 -c 'import ClearLake'

clean:
	rm -rf $(BUILD_DIR)
