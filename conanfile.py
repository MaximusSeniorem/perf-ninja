import os

from conan import ConanFile
from conan.tools.cmake import CMakeToolchain, CMake, cmake_layout
from conan.tools.files import copy
from conan.tools.env import VirtualBuildEnv

class NinjaConan(ConanFile):
    name = 'ninja-perf'

    settings = 'os', 'compiler', 'build_type', 'arch'

    def requirements(self):
        self.requires('fmt/11.2.0')
        self.requires('benchmark/1.9.5')
        # self.requires('lua/5.4.8')

        self.tool_requires('cmake/[>=3.23 <4]')

    def layout(self):
        cmake_layout(self)

    generators = 'CMakeConfigDeps', 'CMakeToolchain', 'VirtualBuildEnv'

    def build(self):
        cmake = CMake(self)

        cmake.configure()
        cmake.build()
