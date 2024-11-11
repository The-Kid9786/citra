HAVE_DYNARMIC = 0
HAVE_GLAD = 1
HAVE_SSE = 0
HAVE_RGLGEN = 0
HAVE_RPC = 1

TARGET_NAME    := citra
EXTERNALS_DIR  += ./externals
SRC_DIR        += ./src
LIBS		   = -lm
DEFINES        := -DHAVE_LIBRETRO

STATIC_LINKING := 0
AR             := ar

SPACE :=
SPACE := $(SPACE) $(SPACE)
BACKSLASH :=
BACKSLASH := \$(BACKSLASH)
filter_out1 = $(filter-out $(firstword $1),$1)
filter_out2 = $(call filter_out1,$(call filter_out1,$1))

ifeq ($(platform),)
platform = unix
ifeq ($(shell uname -a),)
   platform = win
else ifneq ($(findstring MINGW,$(shell uname -a)),)
   platform = win
else ifneq ($(findstring Darwin,$(shell uname -a)),)
   platform = osx
else ifneq ($(findstring win,$(shell uname -a)),)
   platform = win
endif
endif

ifeq (,$(ARCH))
	ARCH = $(shell uname -m)
endif

# system platform
system_platform = unix
ifeq ($(shell uname -a),)
	EXE_EXT = .exe
	system_platform = win
else ifneq ($(findstring Darwin,$(shell uname -a)),)
	system_platform = osx
	arch = intel
ifeq ($(shell uname -p),powerpc)
	arch = ppc
endif
else ifneq ($(findstring MINGW,$(shell uname -a)),)
	system_platform = win
endif

ifeq ($(ARCHFLAGS),)
ifeq ($(archs),ppc)
   ARCHFLAGS = -arch ppc -arch ppc64
else
   ARCHFLAGS = -arch i386 -arch x86_64
endif
endif

ifeq ($(platform), osx)
ifndef ($(NOUNIVERSAL))
   CXXFLAGS += $(ARCHFLAGS)
   LFLAGS += $(ARCHFLAGS)
endif
endif

ifeq ($(STATIC_LINKING), 1)
EXT := a
endif

ifeq ($(platform), unix)
	EXT ?= so
   TARGET := $(TARGET_NAME)_libretro.$(EXT)
   fpic := -fPIC
   SHARED := -shared -Wl,--version-script=$(SRC_DIR)/citra_libretro/link.T -Wl,--no-undefined
   LIBS +=-lpthread -lGL -ldl

#######################################
# Nintendo Switch (libnx)
else ifeq ($(platform), libnx)
   include $(DEVKITPRO)/libnx/switch_rules
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   DEFINES += -DSWITCH=1 -D__SWITCH__=1 -DHAVE_LIBNX=1 \
   -D__LINUX_ERRNO_EXTENSIONS__ -DBOOST_ASIO_DISABLE_SIGACTION -DOS_RNG_AVAILABLE

   fpic := -fPIE
   CFLAGS = $(DEFINES) -I$(LIBNX)/include/ -I$(PORTLIBS)/include/ -specs=$(LIBNX)/switch.specs
   CFLAGS += -march=armv8-a -mtune=cortex-a57 -mtp=soft -mcpu=cortex-a57+crc+fp+simd -ffast-math
   CXXFLAGS = $(ASFLAGS) $(CFLAGS)
   ARCH = aarch64
   STATIC_LINKING = 1
   HAVE_GLAD = 0
   HAVE_RGLGEN = 1
   HAVE_RPC = 0
   DEBUG = 0
else ifneq (,$(findstring windows_msvc2019,$(platform)))
	LIBS =

	PlatformSuffix = $(subst windows_msvc2019_,,$(platform))
	ifneq (,$(findstring desktop,$(PlatformSuffix)))
		WinPartition = desktop
		MSVC2019CompileFlags = -D_UNICODE -DUNICODE -DWINVER=0x0600 -D_WIN32_WINNT=0x0600
		LDFLAGS += -MANIFEST -NXCOMPAT -DYNAMICBASE -DEBUG -OPT:REF -INCREMENTAL:NO -SUBSYSTEM:WINDOWS -MANIFESTUAC:"level='asInvoker' uiAccess='false'" -OPT:ICF -ERRORREPORT:PROMPT -NOLOGO -TLBID:1
	else ifneq (,$(findstring uwp,$(PlatformSuffix)))
		WinPartition = uwp
		MSVC2019CompileFlags = -DWINDLL -D_UNICODE -DUNICODE -DWRL_NO_DEFAULT_LIB
		LDFLAGS += -APPCONTAINER -NXCOMPAT -DYNAMICBASE -MANIFEST:NO -OPT:REF -SUBSYSTEM:CONSOLE -MANIFESTUAC:NO -OPT:ICF -ERRORREPORT:PROMPT -NOLOGO -TLBID:1 -DEBUG:FULL -WINMD:NO
	endif

	ifeq ($(DEBUG), 1)
		MSVC2019CompileFlags += -DEBUG

	else
		MSVC2019CompileFlags += -O2 -GS"-" -MD
	endif

	MSVC2019CompileFlags += -D_WIN32=1 -DNOMINMAX -DBOOST_ALL_NO_LIB

	CFLAGS += $(MSVC2019CompileFlags) -nologo
	CXXFLAGS += $(MSVC2019CompileFlags) -nologo -EHsc -Zc:throwingNew,inline

	TargetArchMoniker = $(subst $(WinPartition)_,,$(PlatformSuffix))

	CC  = cl.exe
	CXX = cl.exe

	SPACE :=
	SPACE := $(SPACE) $(SPACE)
	BACKSLASH :=
	BACKSLASH := \$(BACKSLASH)
	filter_out1 = $(filter-out $(firstword $1),$1)
	filter_out2 = $(call filter_out1,$(call filter_out1,$1))

	reg_query = $(call filter_out2,$(subst $2,,$(shell reg query "$2" -v "$1" 2>/dev/null)))
	fix_path = $(subst $(SPACE),\ ,$(subst \,/,$1))

	b1 := (
	b2 := )
	ProgramFiles86w := $(ProgramFiles$(b1)x86$(b2))
	ProgramFiles86 := $(shell cygpath "$(ProgramFiles86w)")

	WindowsSdkDir ?= $(call reg_query,InstallationFolder,HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Microsoft SDKs\Windows\v10.0)
	WindowsSdkDir ?= $(call reg_query,InstallationFolder,HKEY_CURRENT_USER\SOFTWARE\Wow6432Node\Microsoft\Microsoft SDKs\Windows\v10.0)
	WindowsSdkDir ?= $(call reg_query,InstallationFolder,HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v10.0)
	WindowsSdkDir ?= $(call reg_query,InstallationFolder,HKEY_CURRENT_USER\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v10.0)
	WindowsSdkDir := $(WindowsSdkDir)

	WindowsSDKVersion ?= $(firstword $(foreach folder,$(subst $(subst \,/,$(WindowsSdkDir)Include/),,$(wildcard $(call fix_path,$(WindowsSdkDir)Include\*))),$(if $(wildcard $(call fix_path,$(WindowsSdkDir)Include/$(folder)/um/Windows.h)),$(folder),)))$(BACKSLASH)
	WindowsSDKVersion := $(WindowsSDKVersion)

	VsInstallBuildTools = $(ProgramFiles86)/Microsoft Visual Studio/2019/BuildTools
	VsInstallEnterprise = $(ProgramFiles86)/Microsoft Visual Studio/2019/Enterprise
	VsInstallProfessional = $(ProgramFiles86)/Microsoft Visual Studio/2019/Professional
	VsInstallCommunity = $(ProgramFiles86)/Microsoft Visual Studio/2019/Community

	VsInstallRoot ?= $(shell if [ -d "$(VsInstallBuildTools)" ]; then echo "$(VsInstallBuildTools)"; fi)
	ifeq ($(VsInstallRoot), )
		VsInstallRoot = $(shell if [ -d "$(VsInstallEnterprise)" ]; then echo "$(VsInstallEnterprise)"; fi)
	endif
	ifeq ($(VsInstallRoot), )
		VsInstallRoot = $(shell if [ -d "$(VsInstallProfessional)" ]; then echo "$(VsInstallProfessional)"; fi)
	endif
	ifeq ($(VsInstallRoot), )
		VsInstallRoot = $(shell if [ -d "$(VsInstallCommunity)" ]; then echo "$(VsInstallCommunity)"; fi)
	endif
	VsInstallRoot := $(VsInstallRoot)

	VcCompilerToolsVer := $(shell cat "$(VsInstallRoot)/VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt" | grep -o '[0-9\.]*')
	VcCompilerToolsDir := $(VsInstallRoot)/VC/Tools/MSVC/$(VcCompilerToolsVer)
	VcCompilerLibDir := $(VcCompilerToolsDir)/lib/$(TargetArchMoniker)

	WindowsSDKSharedIncludeDir := $(shell cygpath -w "$(WindowsSdkDir)\Include\$(WindowsSDKVersion)\shared")
	WindowsSDKUCRTIncludeDir := $(shell cygpath -w "$(WindowsSdkDir)\Include\$(WindowsSDKVersion)\ucrt")
	WindowsSDKUMIncludeDir := $(shell cygpath -w "$(WindowsSdkDir)\Include\$(WindowsSDKVersion)\um")
	WindowsSDKUCRTLibDir := $(shell cygpath -w "$(WindowsSdkDir)\Lib\$(WindowsSDKVersion)\ucrt\$(TargetArchMoniker)")
	WindowsSDKUMLibDir := $(shell cygpath -w "$(WindowsSdkDir)\Lib\$(WindowsSDKVersion)\um\$(TargetArchMoniker)")

	LIB := $(shell IFS=$$'\n'; cygpath -w "$(VcCompilerLibDir)")
	INCLUDE := $(shell IFS=$$'\n'; cygpath -w "$(VcCompilerToolsDir)/include")

# For some reason the HostX86 compiler doesn't like compiling for x64
# ("no such file" opening a shared library), and vice-versa.
# Work around it for now by using the strictly x86 compiler for x86, and x64 for x64.
# NOTE: What about ARM?
	ifneq (,$(findstring x64,$(TargetArchMoniker)))
		override TARGET_ARCH = x86_64
		VCCompilerToolsBinDir := $(VcCompilerToolsDir)/bin/HostX64/$(TargetArchMoniker)
      	LIB := $(LIB);$(CORE_DIR)/dx9sdk/Lib/x64
	else
		override TARGET_ARCH = x86
		VCCompilerToolsBinDir := $(VcCompilerToolsDir)/bin/HostX86/$(TargetArchMoniker)
      	LIB := $(LIB);$(CORE_DIR)/dx9sdk/Lib/x86
	endif

	PATH := $(shell IFS=$$'\n'; cygpath "$(VCCompilerToolsBinDir)"):$(PATH)
	PATH := $(PATH):$(shell IFS=$$'\n'; cygpath "$(VsInstallRoot)/Common7/IDE")

	export INCLUDE := $(INCLUDE);$(WindowsSDKSharedIncludeDir);$(WindowsSDKUCRTIncludeDir);$(WindowsSDKUMIncludeDir)
	export LIB := $(LIB);$(WindowsSDKUCRTLibDir);$(WindowsSDKUMLibDir)
	TARGET := $(TARGET_NAME)_libretro.dll
	PSS_STYLE :=2
	LDFLAGS += -DLL
	PLATFORM_EXT = win32
	LDFLAGS += ws2_32.lib user32.lib shell32.lib winmm.lib gdi32.lib opengl32.lib imm32.lib ole32.lib oleaut32.lib version.lib uuid.lib mfuuid.lib
	HAVE_MF = 1
	# RPC crashes, TODO: Figure out why
	HAVE_RPC = 0
else
   CC ?= gcc
   TARGET := $(TARGET_NAME)_libretro.dll
   DEFINES += -D_WIN32_WINNT=0x0600 -DWINVER=0x0600
   SHARED := -shared -static-libgcc -static-libstdc++ -s -Wl,--version-script=$(SRC_DIR)/citra_libretro/link.T -Wl,--no-undefined
   LDFLAGS += -static -lm -ldinput8 -ldxguid -ldxerr8 -luser32 -lgdi32 -lwinmm -limm32 -lole32 -loleaut32 -lshell32 -lversion -luuid -lws2_32

   ifeq ($(MSYSTEM),MINGW64)
   	  CC ?= x86_64-w64-mingw32-gcc
          CXX ?= x86_64-w64-mingw32-g++
	  LDFLAGS += -lopengl32 -lmfuuid
	  ASFLAGS += -DWIN64
	  HAVE_MF = 1
   endif
endif

ifneq (,$(findstring msvc,$(platform)))
CFLAGS += -D_CRT_SECURE_NO_WARNINGS
CXXFLAGS += -D_CRT_SECURE_NO_WARNINGS
endif

# x86_64 is expected to support both SSE and Dynarmic
ifeq ($(ARCH), x86_64)
DEFINES += -DARCHITECTURE_x86_64
HAVE_DYNARMIC = 1
HAVE_SSE = 1
endif

ifeq ($(DEBUG), 1)
   CXXFLAGS += -O0 -g
else
# Add Unix optimization flags
	ifeq (,$(findstring msvc,$(platform)))
   		CXXFLAGS += -O3 -ffast-math -ftree-vectorize -DNDEBUG
	endif
endif

include Makefile.common

SOURCES_C += $(DYNARMICSOURCES_C) $(FAAD2SOURCES_C) $(LIBRESSLSOURCES_C)
SOURCES_CXX += $(DYNARMICSOURCES_CXX)

CPPFILES = $(filter %.cpp,$(SOURCES_CXX))
CCFILES = $(filter %.cc,$(SOURCES_CXX))

OBJECTS := $(SOURCES_C:.c=.o) $(CPPFILES:.cpp=.o) $(CCFILES:.cc=.o)

ifeq (,$(findstring msvc,$(platform)))
	CXXFLAGS += -std=c++20
else
	CXXFLAGS += -std:c++latest
endif


CFLAGS   	  += -D__LIBRETRO__ $(fpic) $(DEFINES) $(INCFLAGS) $(INCFLAGS_PLATFORM)
DYNARMICFLAGS += -D__LIBRETRO__ $(fpic) $(DEFINES) $(DYNARMICINCFLAGS) $(INCFLAGS_PLATFORM) $(CXXFLAGS)
CXXFLAGS 	  += -D__LIBRETRO__ $(fpic) $(DEFINES) $(INCFLAGS) $(INCFLAGS_PLATFORM)

OBJOUT   = -o
LINKOUT  = -o

ifneq (,$(findstring msvc,$(platform)))
	OBJOUT = -Fo
	LINKOUT = -out:
ifeq ($(STATIC_LINKING),1)
	LD ?= lib.exe

	ifeq ($(DEBUG), 1)
		CFLAGS += -MTd
		CXXFLAGS += -MTd
	else
		CFLAGS += -MT
		CXXFLAGS += -MT
	endif
else
	LD = link.exe

	ifeq ($(DEBUG), 1)
		CFLAGS += -MDd
		CXXFLAGS += -MDd
	else
		CFLAGS += -MD
		CXXFLAGS += -MD
	endif
endif
else
	LD = $(CXX)
endif

all: shaders $(TARGET)

$(TARGET): $(OBJECTS)
ifeq ($(STATIC_LINKING), 1)
	$(AR) rcs $@ $(OBJECTS)
else
	$(LD) $(fpic) $(SHARED) $(INCLUDES) $(LINKOUT)$@ $(OBJECTS) $(LDFLAGS) $(LIBS)
endif

$(foreach p,$(OBJECTS),$(if $(findstring $(EXTERNALS_DIR)/dynarmic/src,$p),$p,)):
	$(CXX) $(DYNARMICFLAGS) $(fpic) -c $(OBJOUT)$@ $(@:.o=.cpp)

$(foreach p,$(OBJECTS),$(if $(findstring $(EXTERNALS_DIR)/dynarmic/externals/mcl,$p),$p,)):
	$(CXX) $(DYNARMICFLAGS) $(fpic) -c $(OBJOUT)$@ $(@:.o=.cpp)

$(foreach p,$(OBJECTS),$(if $(findstring $(EXTERNALS_DIR)/dynarmic/externals/zy,$p),$p,)):
	$(CC) $(CFLAGS) $(DYNARMICINCFLAGS) $(fpic) -c $(OBJOUT)$@ $(@:.o=.c)

$(foreach p,$(OBJECTS),$(if $(findstring $(EXTERNALS_DIR)/faad2,$p),$p,)):
	$(CC) $(CFLAGS) $(FAAD2FLAGS) $(fpic) -c $(OBJOUT)$@ $(@:.o=.c)

$(foreach p,$(OBJECTS),$(if $(findstring $(EXTERNALS_DIR)/libressl,$p),$p,)):
	$(CC) $(LIBRESSLFLAGS) $(CFLAGS) $(fpic) -c $(OBJOUT)$@ $(@:.o=.c)

%.o: %.c
	$(CC) $(CFLAGS) $(fpic) -c $(OBJOUT)$@ $<

%.o: %.cc
	$(CXX) $(CXXFLAGS) $(fpic) -c $(OBJOUT)$@ $<

%.o: %.cpp $(EXTERNALS_DIR)/glslang/build/glslang/build_info.h
	$(CXX) $(CXXFLAGS) $(fpic) -c $(OBJOUT)$@ $<

GIT_REV := $(shell git rev-parse HEAD || echo unknown)
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD || echo unknown)
GIT_DESC := $(shell git describe --always --long --dirty || echo unknown)
GIT_COMMIT_DATE := $(shell git log -n1 --date=format-local:'%y%m%d' --format='%cd')
BUILD_DATE := $(shell date +'%Y-%m-%d_%H:%M%z')

$(SRC_DIR)/common/scm_rev.cpp: $(SHADER_CACHE_DEPENDS)
	cat src/common/scm_rev.cpp.in | sed -e 's/@GIT_REV@/$(GIT_REV)/' \
		-e 's/@GIT_BRANCH@/$(GIT_BRANCH)/' \
		-e 's/@GIT_DESC@/$(GIT_COMMIT_DATE)+$(GIT_DESC)/' \
		-e 's/@REPO_NAME@/citra-libretro/' \
		-e 's/@BUILD_DATE@/$(BUILD_DATE)/' \
		-e 's/@BUILD_VERSION@/$(GIT_BRANCH)-$(GIT_DESC)/' \
		-e 's/@BUILD_FULLNAME@//' \
		-e 's/@SHADER_CACHE_VERSION@/$(shell sha1sum $(SHADER_CACHE_DEPENDS) | sha1sum | cut -d" " -f1)/' > $@

$(EXTERNALS_DIR)/glslang/build/glslang/build_info.h: $(EXTERNALS_DIR)/glslang/build_info.h.tmpl $(EXTERNALS_DIR)/glslang/CHANGES.md
	python3 $(EXTERNALS_DIR)/glslang/build_info.py $(EXTERNALS_DIR)/glslang \
		-i $(EXTERNALS_DIR)/glslang/build_info.h.tmpl \
		-o $(EXTERNALS_DIR)/glslang/build/glslang/build_info.h

genfiles: $(SRC_DIR)/common/scm_rev.cpp $(EXTERNALS_DIR)/glslang/build/glslang/build_info.h

clean:
	rm -f $(OBJECTS) $(TARGET) $(SRC_DIR)/common/scm_rev.cpp
	rm -rf $(SRC_DIR)/video_core/shaders

GLSLANG := glslang
ifeq (, $(shell which $(GLSLANG)))
GLSLANG := glslangValidator
ifeq (, $(shell which $(GLSLANG)))
$(error Required program `glslang` (or `glslangValidator`) not found.)
endif
endif

shaders: $(SHADER_FILES)
	for SHADER_FILE in $^; do \
		OUT_DIR=$$(dirname "$(SRC_DIR)/video_core/shaders/$$SHADER_FILE"); \
		FILENAME=$$(basename "$$SHADER_FILE"); \
		SHADER_NAME=$$(echo "$$FILENAME" | sed -e 's/\./_/g'); \
		OUT_FILE="$$OUT_DIR/$$SHADER_NAME"; \
		if [ "$$FILENAME" = "$${FILENAME#vulkan}" ]; then \
			SHADER_CONTENT=$$(cat $$SHADER_FILE | sed -e 's/"/'\''/g'); \
			SHADER_CONTENT=$$(echo "$$SHADER_CONTENT" | sed -e 's/.*/"&'\\\\\\\\'n"/'); \
			mkdir -p "$$OUT_DIR"; \
			echo "$$SHADER_CONTENT" > $$OUT_FILE; \
			cat $(SRC_DIR)/video_core/host_shaders/source_shader.h.in | sed -e "s/@CONTENTS_NAME@/$$(echo $$SHADER_NAME | tr '[a-z]' '[A-Z]')/" > $$OUT_FILE.h; \
			sed -i -e "/@CONTENTS@/ { r $$OUT_FILE" -e "d }" $$OUT_FILE.h; \
			rm -f $$OUT_FILE; \
		fi; \
		if [ "$$FILENAME" = "$${FILENAME#opengl}" ]; then \
			SHADER_NAME=$${SHADER_NAME}_spv; \
			$(GLSLANG) --target-env vulkan1.1 --glsl-version 450 -Dgl_VertexID=gl_VertexIndex \
				--variable-name $$(echo $$SHADER_NAME | tr '[a-z]' '[A-Z]') -o $${OUT_FILE}_spv.h $$SHADER_FILE; \
		fi; \
	done


.PHONY: clean shaders genfiles
