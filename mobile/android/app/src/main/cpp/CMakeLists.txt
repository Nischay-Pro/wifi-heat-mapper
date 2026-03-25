cmake_minimum_required(VERSION 3.22.1)

project(whm_iperf)

set(IPERF_DIR ${CMAKE_CURRENT_LIST_DIR}/../../../../../external/iperf/src)

configure_file(
  ${CMAKE_CURRENT_LIST_DIR}/version.h.in
  ${CMAKE_CURRENT_BINARY_DIR}/generated/version.h
  @ONLY
)

add_executable(
  libiperf_bundle.so
  ${IPERF_DIR}/cjson.c
  ${IPERF_DIR}/dscp.c
  ${IPERF_DIR}/iperf_api.c
  ${IPERF_DIR}/iperf_auth.c
  ${IPERF_DIR}/iperf_client_api.c
  ${IPERF_DIR}/iperf_error.c
  ${IPERF_DIR}/iperf_locale.c
  ${IPERF_DIR}/iperf_pthread.c
  ${IPERF_DIR}/iperf_sctp.c
  ${IPERF_DIR}/iperf_server_api.c
  ${IPERF_DIR}/iperf_tcp.c
  ${IPERF_DIR}/iperf_time.c
  ${IPERF_DIR}/iperf_udp.c
  ${IPERF_DIR}/iperf_util.c
  ${IPERF_DIR}/main.c
  ${IPERF_DIR}/net.c
  ${IPERF_DIR}/tcp_info.c
  ${IPERF_DIR}/timer.c
  ${IPERF_DIR}/units.c
)

target_include_directories(
  libiperf_bundle.so
  PRIVATE
  ${IPERF_DIR}
  ${CMAKE_CURRENT_LIST_DIR}
  ${CMAKE_CURRENT_BINARY_DIR}/generated
)

target_compile_definitions(
  libiperf_bundle.so
  PRIVATE
  HAVE_CONFIG_H
  HAVE_CLOCK_GETTIME=1
  HAVE_CLOCK_NANOSLEEP=1
  HAVE_DLFCN_H=1
  HAVE_ENDIAN_H=1
  HAVE_GETLINE=1
  HAVE_INTTYPES_H=1
  HAVE_LINUX_TCP_H=1
  HAVE_POLL_H=1
  HAVE_PTHREAD=1
  HAVE_STDINT_H=1
  HAVE_STDIO_H=1
  HAVE_STDLIB_H=1
  HAVE_STRINGS_H=1
  HAVE_STRING_H=1
  HAVE_SYS_SOCKET_H=1
  HAVE_SYS_STAT_H=1
  HAVE_SYS_TYPES_H=1
  HAVE_UNISTD_H=1
  STDC_HEADERS=1
  HAVE_TCP_CONGESTION=1
  HAVE_TCP_KEEPALIVE=1
  HAVE_TCP_USER_TIMEOUT=1
  HAVE_SO_MAX_PACING_RATE=1
  HAVE_MSG_TRUNC=1
  PACKAGE_VERSION=\"3.20\"
  VERSION=\"3.20\"
)

target_compile_options(
  libiperf_bundle.so
  PRIVATE
  -Wno-error=format-security
  -Wno-format-security
  -fPIE
  -pie
)

target_link_libraries(libiperf_bundle.so PRIVATE log m)
