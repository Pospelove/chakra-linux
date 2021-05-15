vcpkg_fail_port_install(ON_TARGET osx uwp)

if (WIN32)
    vcpkg_fail_port_install(ON_CRT_LINKAGE static ON_LIBRARY_LINKAGE static)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO Microsoft/ChakraCore
    REF 8220c858e58a2d15a08d86c7e600490620704169
    SHA512 ab3f67284a1593cad8bd7ce97496ef54257c20e5f0c346a91dfe342464d0c8d1b7675bf1bbdf4601be5c40ef0f5b1f481d278f8d16f0f32772489299031f7018
    HEAD_REF master
)

if(WIN32)
    find_path(COR_H_PATH cor.h)
    if(COR_H_PATH MATCHES "NOTFOUND")
        message(FATAL_ERROR "Could not find <cor.h>. Ensure the NETFXSDK is installed.")
    endif()
    get_filename_component(NETFXSDK_PATH "${COR_H_PATH}/../.." ABSOLUTE)
endif()

set(BUILDTREE_PATH ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET})
file(REMOVE_RECURSE ${BUILDTREE_PATH})
file(COPY ${SOURCE_PATH}/ DESTINATION ${BUILDTREE_PATH})

set(CHAKRA_RUNTIME_LIB "static_library") # ChakraCore only supports static CRT linkage

if(WIN32)
    vcpkg_build_msbuild(
        PROJECT_PATH ${BUILDTREE_PATH}/Build/Chakra.Core.sln
        OPTIONS
            "/p:DotNetSdkRoot=${NETFXSDK_PATH}/"
            "/p:CustomBeforeMicrosoftCommonTargets=${CMAKE_CURRENT_LIST_DIR}/no-warning-as-error.props"
            "/p:RuntimeLib=${CHAKRA_RUNTIME_LIB}"
    )
else()
    vcpkg_find_acquire_program(PYTHON2)
    get_filename_component(PYTHON2_EXE_PATH ${PYTHON2} DIRECTORY)
    vcpkg_add_to_path("${PYTHON2_EXE_PATH}")

    #file(READ ${BUILDTREE_PATH}/CMakeLists.txt CCCC)
    #string(REPLACE "add_subdirectory (pal)" "" CCCC "${CCCC}")
    #string(REPLACE "add_subdirectory (bin)" "" CCCC "${CCCC}")
    #string(REPLACE "add_subdirectory(test)" "" CCCC "${CCCC}")
    #file(WRITE ${BUILDTREE_PATH}/CMakeLists.txt "${CCCC}")
#file(DOWNLOAD 
#https://raw.githubusercontent.com/Pospelove/ChakraCore/master/lib/CMakeLists.txt 
#    ${BUILDTREE_PATH}/lib/CMakeLists.txt)
#    file(DOWNLOAD 
#    https://raw.githubusercontent.com/Pospelove/ChakraCore/master/lib/Runtime/CMakeLists.txt
#    ${BUILDTREE_PATH}/lib/Runtime/CMakeLists.txt)

    file(DOWNLOAD 
https://raw.githubusercontent.com/Pospelove/ChakraCore/master/bin/ch/ch.cpp 
    ${BUILDTREE_PATH}/bin/ch/ch.cpp)
    file(DOWNLOAD 
    https://raw.githubusercontent.com/Pospelove/ChakraCore/master/bin/ch/stdafx.h
    ${BUILDTREE_PATH}/bin/ch/stdafx.h)


    file(READ ${BUILDTREE_PATH}/build.sh BUILD_SH_CONTENTS)
    set(BUILD_SH_CONTENTS "#!/bin/bash\n${BUILD_SH_CONTENTS}")
    string(REPLACE "VERSION=$($CLANG_PATH --version | grep \"version [0-9]*\\.[0-9]*\" --o -i | grep \"[0-9]*\\.[0-9]*\" --o)\n" "" BUILD_SH_CONTENTS "${BUILD_SH_CONTENTS}")
    string(REPLACE "VERSION=\${VERSION/./}" "VERSION=37" BUILD_SH_CONTENTS "${BUILD_SH_CONTENTS}")
    file(WRITE ${BUILDTREE_PATH}/build.sh "${BUILD_SH_CONTENTS}")

    file(READ ${BUILDTREE_PATH}/pal/src/safecrt/input.inl INPUT_INL_CONTENTS)
    string(REPLACE "__uint64_t num64 = 0LL" "typedef unsigned long __uint64_t;\n__uint64_t num64 = 0LL" INPUT_INL_CONTENTS "${INPUT_INL_CONTENTS}")
    file(WRITE ${BUILDTREE_PATH}/pal/src/safecrt/input.inl "${INPUT_INL_CONTENTS}")

    file(READ ${BUILDTREE_PATH}/pal/src/safecrt/output.inl OUTPUT_INL_CONTENTS)
    string(REPLACE "typedef double  _CRT_DOUBLE;" "" OUTPUT_INL_CONTENTS "${OUTPUT_INL_CONTENTS}")
    string(REPLACE "_CRT_DOUBLE" "double" OUTPUT_INL_CONTENTS "${OUTPUT_INL_CONTENTS}")
    string(REPLACE "__uint64_t" "unsigned long" OUTPUT_INL_CONTENTS "${OUTPUT_INL_CONTENTS}")
    string(REPLACE "//#include <stdarg.h>" "#include <stdarg.h>" OUTPUT_INL_CONTENTS "${OUTPUT_INL_CONTENTS}")
    file(WRITE ${BUILDTREE_PATH}/pal/src/safecrt/output.inl "${OUTPUT_INL_CONTENTS}")

    file(READ ${BUILDTREE_PATH}/pal/src/loader/module.cpp MODULE_CPP_CONTENTS)
    string(REPLACE "#include <gnu/lib-names.h>" "" MODULE_CPP_CONTENTS "${MODULE_CPP_CONTENTS}")
    string(REPLACE "shortAsciiName = \"libc.so\";" "shortAsciiName = \"libc.musl-x86_64.so.1\";" MODULE_CPP_CONTENTS "${MODULE_CPP_CONTENTS}")
    file(WRITE ${BUILDTREE_PATH}/pal/src/loader/module.cpp "${MODULE_CPP_CONTENTS}")

    file(READ ${BUILDTREE_PATH}/pal/src/locale/unicode.cpp UNICODE_CPP_CONTENTS)
    string(REPLACE "#include <libintl.h>" "" UNICODE_CPP_CONTENTS "${UNICODE_CPP_CONTENTS}")
    string(REPLACE "LPCSTR resourceString = dgettext(lpDomain, lpResourceStr);" "LPCSTR resourceString = lpResourceStr;" UNICODE_CPP_CONTENTS "${UNICODE_CPP_CONTENTS}")
    file(WRITE ${BUILDTREE_PATH}/pal/src/locale/unicode.cpp "${UNICODE_CPP_CONTENTS}")

    file(READ ${BUILDTREE_PATH}/pal/src/misc/sysinfo.cpp SYSINFO_CPP_CONTENTS)
    string(REPLACE "#if HAVE_SYSCONF && defined(__LINUX__) && !defined(__ANDROID__)" "#if false" SYSINFO_CPP_CONTENTS "${SYSINFO_CPP_CONTENTS}")
    file(WRITE ${BUILDTREE_PATH}/pal/src/misc/sysinfo.cpp "${SYSINFO_CPP_CONTENTS}")

    ## Honestly only line 1070 is wrong
    ## By the way it's fixed in Chakracore master
    ##file(READ ${BUILDTREE_PATH}/pal/inc/rt/palrt.h PALRT_H_CONTENTS)
    ##string(REPLACE "template <size_t _SizeInWords>" "template <size_t _SzInWords>" PALRT_H_CONTENTS "${PALRT_H_CONTENTS}")
    ##file(WRITE ${BUILDTREE_PATH}/pal/inc/rt/palrt.h "${PALRT_H_CONTENTS}")

    #file(DOWNLOAD 
    #https://raw.githubusercontent.com/chakra-core/ChakraCore/1eae003b7a981b4b691928daef27b5254a49f5eb/pal/inc/rt/palrt.h 
    #${BUILDTREE_PATH}/pal/inc/rt/palrt.h)

    #file(READ ${BUILDTREE_PATH}/lib/Common/DataStructures/Comparer.h COMPARER_H_CONTENTS)
    #string(REPLACE "template <typename T> class TComparerType : public TComparer {};" "template <typename T1> class TComparerType : public TComparer {};" COMPARER_H_CONTENTS "${COMPARER_H_CONTENTS}")
    #file(WRITE ${BUILDTREE_PATH}/lib/Common/DataStructures/Comparer.h "${COMPARER_H_CONTENTS}")

    #file(READ ${BUILDTREE_PATH}/lib/Common/Memory/SmallLeafHeapBucket.h SMALL_LEAF_HEAP_BUCKET_H_CONTENTS)
    #string(REPLACE " template <class TBlockAttributes>" " template <class TBlockAttributes1>" SMALL_LEAF_HEAP_BUCKET_H_CONTENTS "${SMALL_LEAF_HEAP_BUCKET_H_CONTENTS}")
    #file(WRITE ${BUILDTREE_PATH}/lib/Common/Memory/SmallLeafHeapBucket.h "${SMALL_LEAF_HEAP_BUCKET_H_CONTENTS}")

    #file(READ ${BUILDTREE_PATH}/lib/Common/DataStructures/List.h LIST_H_CONTENTS)
    #string(REPLACE "template<class TAllocator>" "template<class TAllocator1>" LIST_H_CONTENTS "${LIST_H_CONTENTS}")
    #string(REPLACE "static ReadOnlyList * New(TAllocator* alloc, __in_ecount(count) T* buffer, DECLSPEC_GUARD_OVERFLOW int count)" "static ReadOnlyList * New(TAllocator1* alloc, __in_ecount(count) T* buffer, DECLSPEC_GUARD_OVERFLOW int count)" LIST_H_CONTENTS "${LIST_H_CONTENTS}")
    #string(REPLACE "return AllocatorNew(TAllocator, alloc, ReadOnlyList, buffer, count, alloc);" "return AllocatorNew(TAllocator1, alloc, ReadOnlyList, buffer, count, alloc);" LIST_H_CONTENTS "${LIST_H_CONTENTS}")
    #string(REPLACE "template<class T>" "template<class T1>" LIST_H_CONTENTS "${LIST_H_CONTENTS}")
    #string(REPLACE "void Copy(const T* list)" "void Copy(const T1* list)" LIST_H_CONTENTS "${LIST_H_CONTENTS}")
    #string(REPLACE "CompileAssert(sizeof(TElementType) == sizeof(typename T::TElementType));" "CompileAssert(sizeof(TElementType) == sizeof(typename T1::TElementType));" LIST_H_CONTENTS "${LIST_H_CONTENTS}")
    #file(WRITE ${BUILDTREE_PATH}/lib/Common/DataStructures/List.h "${LIST_H_CONTENTS}")

    #file(READ ${BUILDTREE_PATH}/lib/Runtime/Language/EvalMapRecord.h EVAL_MAP_RECORD_H_CONTENTS)
    #string(REPLACE "template <class T, class Value>" "template <class T, class Value1>" EVAL_MAP_RECORD_H_CONTENTS "${EVAL_MAP_RECORD_H_CONTENTS}")
    #string(REPLACE "AutoRestoreSetInAdd(T* instance, Value1 value) :" "AutoRestoreSetInAdd(T* instance, Value1 value) :" EVAL_MAP_RECORD_H_CONTENTS "${EVAL_MAP_RECORD_H_CONTENTS}")
    #string(REPLACE "Value value;" "Value1 value;" EVAL_MAP_RECORD_H_CONTENTS "${EVAL_MAP_RECORD_H_CONTENTS}")
    #file(WRITE ${BUILDTREE_PATH}/lib/Runtime/Language/EvalMapRecord.h "${EVAL_MAP_RECORD_H_CONTENTS}")

    ##file (READ /usr/include/sys/resource.h resource_h)
    ##message(FATAL_ERROR "${resource_h}")

    file(READ ${BUILDTREE_PATH}/lib/Backend/amd64/md.h MD_H_CONTENTS)
    string(REPLACE "const int PAGESIZE = 2 * 0x1000;" "#ifdef PAGESIZE\n#undef PAGESIZE\n#endif\nconst int PAGESIZE = 2 * 0x1000;" MD_H_CONTENTS "${MD_H_CONTENTS}")
    file(WRITE ${BUILDTREE_PATH}/lib/Backend/amd64/md.h "${MD_H_CONTENTS}")

    file(READ ${BUILDTREE_PATH}/lib/Backend/i386/md.h MD_H_CONTENTS)
    string(REPLACE "const int PAGESIZE = 0x1000;" "#ifdef PAGESIZE\n#undef PAGESIZE\n#endif\nconst int PAGESIZE = 0x1000;" MD_H_CONTENTS "${MD_H_CONTENTS}")
    file(WRITE ${BUILDTREE_PATH}/lib/Backend/i386/md.h "${MD_H_CONTENTS}")

    file(READ ${BUILDTREE_PATH}/lib/Runtime/Language/AsmJsJitTemplate.h MD_H_CONTENTS)
    string(REPLACE "const int PAGESIZE = 0x1000;" "#ifdef PAGESIZE\n#undef PAGESIZE\n#endif\nconst int PAGESIZE = 0x1000;" MD_H_CONTENTS "${MD_H_CONTENTS}")
    file(WRITE ${BUILDTREE_PATH}/lib/Runtime/Language/AsmJsJitTemplate.h "${MD_H_CONTENTS}")

    file(READ ${BUILDTREE_PATH}/lib/Runtime/PlatformAgnostic/Platform/Linux/SystemInfo.cpp SYSTEM_INFO_CPP_CONTENTS)
    string(REPLACE "#include \"Common.h\"" "" SYSTEM_INFO_CPP_CONTENTS "${SYSTEM_INFO_CPP_CONTENTS}")
    string(REPLACE "#include \"ChakraPlatform.h\"" "" SYSTEM_INFO_CPP_CONTENTS "${SYSTEM_INFO_CPP_CONTENTS}")
    string(REPLACE "#include <sys/resource.h>" "#include <sys/resource.h>\n#include \"Common.h\"\n#include \"ChakraPlatform.h\"" SYSTEM_INFO_CPP_CONTENTS "${SYSTEM_INFO_CPP_CONTENTS}")
    file(WRITE ${BUILDTREE_PATH}/lib/Runtime/PlatformAgnostic/Platform/Linux/SystemInfo.cpp "${SYSTEM_INFO_CPP_CONTENTS}")

    #vcpkg_cmake_build(TARGETS Chakra.Runtime.PlatformAgnostic)

    execute_process(
        COMMAND bash "build.sh"
        WORKING_DIRECTORY ${BUILDTREE_PATH}
        #OUTPUT_VARIABLE CHAKRA_BUILD_SH_OUT
        #ERROR_VARIABLE CHAKRA_BUILD_SH_ERR
        #RESULT_VARIABLE CHAKRA_BUILD_SH_RES
        #ECHO_OUTPUT_VARIABLE
        #ECHO_ERROR_VARIABLE
    )
    #message(STATUS ${CHAKRA_BUILD_SH_RES})
    #message(STATUS ------)
    #message(STATUS ${CHAKRA_BUILD_SH_OUT})
    #message(STATUS ------)
    #message(STATUS ${CHAKRA_BUILD_SH_ERR})
    message(FATAL_ERROR KEK)


endif()

if (WIN32)
    set(JSRT_DIRECTORY_NAME jsrt)
else()
    set(JSRT_DIRECTORY_NAME Jsrt)
endif()

file(INSTALL
    ${BUILDTREE_PATH}/lib/${JSRT_DIRECTORY_NAME}/ChakraCore.h
    ${BUILDTREE_PATH}/lib/${JSRT_DIRECTORY_NAME}/ChakraCommon.h
    ${BUILDTREE_PATH}/lib/${JSRT_DIRECTORY_NAME}/ChakraDebug.h
    DESTINATION ${CURRENT_PACKAGES_DIR}/include
)
if(WIN32)
    file(INSTALL
        ${BUILDTREE_PATH}/lib/${JSRT_DIRECTORY_NAME}/ChakraCommonWindows.h
        DESTINATION ${CURRENT_PACKAGES_DIR}/include
    )
    if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
        file(INSTALL
            ${BUILDTREE_PATH}/Build/VcBuild/bin/${TRIPLET_SYSTEM_ARCH}_debug/ChakraCore.dll
            ${BUILDTREE_PATH}/Build/VcBuild/bin/${TRIPLET_SYSTEM_ARCH}_debug/ChakraCore.pdb
            DESTINATION ${CURRENT_PACKAGES_DIR}/debug/bin
        )
        file(INSTALL
            ${BUILDTREE_PATH}/Build/VcBuild/bin/${TRIPLET_SYSTEM_ARCH}_debug/Chakracore.lib
            DESTINATION ${CURRENT_PACKAGES_DIR}/debug/lib
        )
    endif()
    if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "release")
        file(INSTALL
            ${BUILDTREE_PATH}/Build/VcBuild/bin/${TRIPLET_SYSTEM_ARCH}_release/ChakraCore.dll
            ${BUILDTREE_PATH}/Build/VcBuild/bin/${TRIPLET_SYSTEM_ARCH}_release/ChakraCore.pdb
            DESTINATION ${CURRENT_PACKAGES_DIR}/bin
        )
        file(INSTALL
            ${BUILDTREE_PATH}/Build/VcBuild/bin/${TRIPLET_SYSTEM_ARCH}_release/Chakracore.lib
            DESTINATION ${CURRENT_PACKAGES_DIR}/lib
        )
        file(INSTALL
            ${BUILDTREE_PATH}/Build/VcBuild/bin/${TRIPLET_SYSTEM_ARCH}_release/ch.exe
            ${BUILDTREE_PATH}/Build/VcBuild/bin/${TRIPLET_SYSTEM_ARCH}_release/GCStress.exe
            ${BUILDTREE_PATH}/Build/VcBuild/bin/${TRIPLET_SYSTEM_ARCH}_release/rl.exe
            DESTINATION ${CURRENT_PACKAGES_DIR}/tools/chakracore)
        vcpkg_copy_tool_dependencies(${CURRENT_PACKAGES_DIR}/tools/chakracore)
    endif()
    vcpkg_copy_pdbs()
else()

endif()

if(WIN32)
    set(LICENSE_DESTINATION ${CURRENT_PACKAGES_DIR}/share/ChakraCore)
else()
    set(LICENSE_DESTINATION ${CURRENT_PACKAGES_DIR}/share/chakracore)
endif()
file(INSTALL
    ${SOURCE_PATH}/LICENSE.txt
    DESTINATION ${LICENSE_DESTINATION} RENAME copyright)