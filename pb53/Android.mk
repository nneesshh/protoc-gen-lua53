LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := pb_static

LOCAL_MODULE_FILENAME := libpb

LOCAL_SRC_FILES := \
src/pb.c

LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/../lua/luajit/include

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../lua/luajit/include
                                 
include $(BUILD_STATIC_LIBRARY)
