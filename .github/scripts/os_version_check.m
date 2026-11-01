// The iOS toolchain Theos installs on Linux ships without compiler-rt, so code that uses
// @available fails to link: the check calls a helper that Xcode's copy of compiler-rt
// provides. setup_theos_linux.sh compiles this file into libclang_rt.ios.a in the
// toolchain's resource directory, where clang links it automatically, as Xcode does.
#import <Foundation/Foundation.h>

int32_t __isOSVersionAtLeast(int32_t major, int32_t minor, int32_t subminor);
int32_t __isPlatformVersionAtLeast(uint32_t platform, uint32_t major, uint32_t minor, uint32_t subminor);

__attribute__((visibility("hidden")))
int32_t __isOSVersionAtLeast(int32_t major, int32_t minor, int32_t subminor) {
    NSOperatingSystemVersion version = {major, minor, subminor};
    return [NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:version];
}

// Newer clang versions call this one instead. Everything built here targets iOS, so the
// platform argument is not needed.
__attribute__((visibility("hidden")))
int32_t __isPlatformVersionAtLeast(uint32_t platform, uint32_t major, uint32_t minor, uint32_t subminor) {
    (void)platform;
    return __isOSVersionAtLeast((int32_t)major, (int32_t)minor, (int32_t)subminor);
}
