vcpkg_from_github(
	OUT_SOURCE_PATH SOURCE_PATH
	REPO skyrim-multiplayer/JsEngine
	REF a25c73e09ece2d7a0306146de61074983059ee70
	SHA512 1e40fe52bd5c14b20740ccf7178637b91a03d455e63018968fcb85cf7a40f9b40356d9ccc52d6babbe6e0b1b18ed8465d17cf4d53a776b4c9a15313b1a16f09d
	HEAD_REF master
)

file(GLOB_RECURSE sources ${SOURCE_PATH}/*.h)
foreach(file ${sources})
    file(
        COPY ${file}
        DESTINATION ${CURRENT_PACKAGES_DIR}/include
    )
endforeach()

file(INSTALL ${SOURCE_PATH}/LICENSE DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)