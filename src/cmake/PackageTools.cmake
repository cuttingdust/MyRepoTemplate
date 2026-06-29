# Shared install/export helpers for C++ libraries.
# CommonTools.cmake owns build defaults; this file owns package/export layout.

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

function(cpp_install_package)
	set(options)
	set(oneValueArgs TARGET CONFIG_NAME NAMESPACE VERSION CONFIG_TEMPLATE HEADER_DESTINATION COMPATIBILITY)
	set(multiValueArgs PUBLIC_HEADERS)
	cmake_parse_arguments(CPP_PACKAGE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	if(NOT CPP_PACKAGE_TARGET)
		message(FATAL_ERROR "cpp_install_package: TARGET is required")
	endif()

	if(NOT TARGET ${CPP_PACKAGE_TARGET})
		message(FATAL_ERROR "cpp_install_package: target '${CPP_PACKAGE_TARGET}' does not exist")
	endif()

	if(NOT CPP_PACKAGE_CONFIG_NAME)
		set(CPP_PACKAGE_CONFIG_NAME ${CPP_PACKAGE_TARGET})
	endif()

	if(NOT CPP_PACKAGE_NAMESPACE)
		set(CPP_PACKAGE_NAMESPACE "${CPP_PACKAGE_CONFIG_NAME}::")
	endif()

	if(NOT CPP_PACKAGE_VERSION)
		set(CPP_PACKAGE_VERSION "1.0.0")
	endif()

	if(NOT CPP_PACKAGE_COMPATIBILITY)
		set(CPP_PACKAGE_COMPATIBILITY SameMajorVersion)
	endif()

	if(NOT CPP_PACKAGE_HEADER_DESTINATION)
		set(CPP_PACKAGE_HEADER_DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")
	endif()

	if(NOT CPP_PACKAGE_CONFIG_TEMPLATE)
		message(FATAL_ERROR "cpp_install_package: CONFIG_TEMPLATE is required")
	endif()

	if(NOT EXISTS "${CPP_PACKAGE_CONFIG_TEMPLATE}")
		message(FATAL_ERROR "cpp_install_package: CONFIG_TEMPLATE does not exist: ${CPP_PACKAGE_CONFIG_TEMPLATE}")
	endif()

	set(_package_config_dir "${CMAKE_INSTALL_LIBDIR}/cmake/${CPP_PACKAGE_CONFIG_NAME}")
	set(_package_targets_name "${CPP_PACKAGE_CONFIG_NAME}Targets")

	install(TARGETS ${CPP_PACKAGE_TARGET}
		EXPORT ${_package_targets_name}
		RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
		LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
		ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
	)

	if(CPP_PACKAGE_PUBLIC_HEADERS)
		install(FILES ${CPP_PACKAGE_PUBLIC_HEADERS}
			DESTINATION ${CPP_PACKAGE_HEADER_DESTINATION}
		)
	endif()

	install(EXPORT ${_package_targets_name}
		FILE ${_package_targets_name}.cmake
		NAMESPACE ${CPP_PACKAGE_NAMESPACE}
		DESTINATION ${_package_config_dir}
	)

	configure_package_config_file(
		${CPP_PACKAGE_CONFIG_TEMPLATE}
		${CMAKE_CURRENT_BINARY_DIR}/${CPP_PACKAGE_CONFIG_NAME}Config.cmake
		INSTALL_DESTINATION ${_package_config_dir}
	)

	write_basic_package_version_file(
		${CMAKE_CURRENT_BINARY_DIR}/${CPP_PACKAGE_CONFIG_NAME}ConfigVersion.cmake
		VERSION ${CPP_PACKAGE_VERSION}
		COMPATIBILITY ${CPP_PACKAGE_COMPATIBILITY}
	)

	install(FILES
		${CMAKE_CURRENT_BINARY_DIR}/${CPP_PACKAGE_CONFIG_NAME}Config.cmake
		${CMAKE_CURRENT_BINARY_DIR}/${CPP_PACKAGE_CONFIG_NAME}ConfigVersion.cmake
		DESTINATION ${_package_config_dir}
	)
endfunction()

function(cpp_vcpkg name)
	set(options)
	set(oneValueArgs VERSION CONFIG_NAME NAMESPACE CONFIG_TEMPLATE HEADER_DESTINATION COMPATIBILITY)
	set(multiValueArgs PUBLIC_LIBS PRIVATE_LIBS PUBLIC_HEADERS)
	cmake_parse_arguments(CPP_VCPKG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	message(STATUS "============================================================")
	message(STATUS " cpp_vcpkg: ${name}")
	message(STATUS "============================================================")
	message(STATUS " CMAKE_CURRENT_LIST_DIR : ${CMAKE_CURRENT_LIST_DIR}")

	option(${name}_SHARED "Build ${name} as a shared library" ON)
	message(STATUS " ${name}_SHARED           : ${${name}_SHARED}")

	if(${name}_SHARED)
		set(_cpp_vcpkg_type SHARED)
	else()
		set(_cpp_vcpkg_type STATIC)
	endif()
	message(STATUS " Library type           : ${_cpp_vcpkg_type}")

	if(NOT CPP_VCPKG_VERSION)
		set(CPP_VCPKG_VERSION "1.0.0")
	endif()

	if(NOT CPP_VCPKG_CONFIG_NAME)
		set(CPP_VCPKG_CONFIG_NAME ${name})
	endif()

	if(NOT CPP_VCPKG_NAMESPACE)
		set(CPP_VCPKG_NAMESPACE "${CPP_VCPKG_CONFIG_NAME}::")
	endif()

	message(STATUS " Version                : ${CPP_VCPKG_VERSION}")
	message(STATUS " Config name            : ${CPP_VCPKG_CONFIG_NAME}")
	message(STATUS " Namespace              : ${CPP_VCPKG_NAMESPACE}")
	message(STATUS " Header destination     : ${CPP_VCPKG_HEADER_DESTINATION}")
	message(STATUS " Public libraries       : ${CPP_VCPKG_PUBLIC_LIBS}")
	message(STATUS " Private libraries      : ${CPP_VCPKG_PRIVATE_LIBS}")
	message(STATUS "============================================================")

	get_src_include()

	add_library(${name} ${_cpp_vcpkg_type}
		${UI_FILES}
		${UIC_HEADER}
		${QRC_FILES}
		${QRC_SOURCE_FILES}
		${PROTO_FILES}
		${PROTO_CC_FILE}
		${PROTO_HREADER_FILE}
		${SRC}
		${H_FILE_I}
	)

	set_cpp(${name})

	if(${name}_SHARED)
		target_compile_definitions(${name} PRIVATE ${name}_EXPORTS)
	else()
		target_compile_definitions(${name} PRIVATE ${name}_STATIC)
	endif()

	if(CPP_VCPKG_PUBLIC_LIBS OR CPP_VCPKG_PRIVATE_LIBS)
		target_link_libraries(${name}
			PUBLIC ${CPP_VCPKG_PUBLIC_LIBS}
			PRIVATE ${CPP_VCPKG_PRIVATE_LIBS}
		)
	endif()

	target_compile_features(${name} PUBLIC cxx_std_20)

	cpp_install_package(
		TARGET ${name}
		CONFIG_NAME ${CPP_VCPKG_CONFIG_NAME}
		NAMESPACE ${CPP_VCPKG_NAMESPACE}
		VERSION ${CPP_VCPKG_VERSION}
		PUBLIC_HEADERS ${CPP_VCPKG_PUBLIC_HEADERS}
		HEADER_DESTINATION ${CPP_VCPKG_HEADER_DESTINATION}
		CONFIG_TEMPLATE ${CPP_VCPKG_CONFIG_TEMPLATE}
		COMPATIBILITY ${CPP_VCPKG_COMPATIBILITY}
	)
endfunction()
