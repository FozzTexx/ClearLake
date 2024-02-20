from setuptools import Extension, setup
import os

home = os.environ.get("HOME")

setup(ext_modules=[
  Extension(
    "ClearLake",
    [
      "CLPythonModule.m",
      "CLObjectBridge.m",
      "CLPageBridge.m",
      "CLStreamBridge.m",
      "CLStringBridge.m",
      "CLOptionBridge.m",
      "CLMutableArrayBridge.m",
    ],
    extra_compile_args=[
      "-fconstant-string-class=CLConstantString",
      f"-I{home}/Unix/linux/include",
      "-fPIC",
    ],
    extra_link_args=[
      f"-L{home}/Unix/linux/lib/x86_64",
      "-lClearLake",
      "-lobjc",
      "-lcrypt",
      "-lz",
      "-lcrypto",
      "-lffi",
      "-lhoedown",
      "-lpiclib",
      "-lm",
      "-ljpeg",
      "-lpng",
      "-lpthread",
      "-lgmp",
      "-lpcre",
      "-ltiff",
      "-lutil",
      "-lmysqlclient",
      "-lct",
    ],
  ),
])
