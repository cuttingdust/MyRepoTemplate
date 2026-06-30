# vcpkg Package Registry 制作流程

这份文档记录 `mlog` 这次从普通 CMake 库变成可通过 vcpkg registry 安装的完整流程。以后新建库时，可以按这个流程替换包名、仓库地址、版本号和 commit。

## 目标效果

消费者项目最终只需要：

```json
{
  "dependencies": [ "mlog" ]
}
```

并在 `CMakeLists.txt` 中使用：

```cmake
find_package(MLog CONFIG REQUIRED)
target_link_libraries(my_app PRIVATE MLog::MLog)
```

但是因为 `mlog` 不是 vcpkg 官方库，所以消费者项目还需要一个 `vcpkg-configuration.json` 告诉 vcpkg 去你的个人 registry 查找 `mlog`。

## 整体结构

推荐拆成两个 GitHub 仓库：

```text
api_mlog
  src/
    CMakeLists.txt
    cmake/
      CommonTools.cmake
      PackageTools.cmake
      MLogConfig.cmake.in
    mlog/
      CMakeLists.txt
      include/
      src/

cuttingdust-vcpkg-registry
  ports/
    mlog/
      portfile.cmake
      usage
      vcpkg.json
  versions/
    baseline.json
    m-/
      mlog.json
```

一个 registry 仓库可以放很多库，不需要每个库建一个 registry。

## 第一步：源码库要能 install/export

库本身必须能生成 CMake package，让消费者可以 `find_package`。

在库的 `CMakeLists.txt` 中使用模板里的 `PackageTools.cmake`：

```cmake
include(PackageTools)

cpp_vcpkg(MLog
  CONFIG_NAME MLog
  NAMESPACE MLog::
  VERSION ${MLOG_VERSION}
  PUBLIC_LIBS spdlog::spdlog
  PUBLIC_HEADERS
    ${CMAKE_CURRENT_LIST_DIR}/include/MLog.h
    ${CMAKE_CURRENT_LIST_DIR}/include/MLog_Global.h
  HEADER_DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/MLog
  CONFIG_TEMPLATE ${CMAKE_CURRENT_SOURCE_DIR}/../cmake/MLogConfig.cmake.in
)
```

`MLogConfig.cmake.in` 负责声明包依赖：

```cmake
@PACKAGE_INIT@

include(CMakeFindDependencyMacro)
find_dependency(spdlog CONFIG)

if(NOT TARGET MLog::MLog)
  include("${CMAKE_CURRENT_LIST_DIR}/MLogTargets.cmake")
endif()

check_required_components(MLog)
```

本地先验证：

```powershell
cmake -B build -A x64 -S src
cmake --build build --config Release
cmake --install build --config Release --prefix out/install
```

验证安装目录里应该出现：

```text
out/install/include/MLog/MLog.h
out/install/lib/cmake/MLog/MLogConfig.cmake
out/install/lib/cmake/MLog/MLogTargets.cmake
```

## 第二步：源码库提交并推送

vcpkg port 不能引用一个飘着的分支，应该引用固定 commit。

```powershell
git add src README.md LICENSE
git commit -m "Initial CMake vcpkg package layout"
git push -u origin main
git rev-parse HEAD
```

记下源码 commit，例如这次 `mlog` 是：

```text
af45b6abd4dd68c265d4250da63a5ae79f8b19ce
```

## 第三步：创建 registry 仓库

建议创建一个统一的个人 registry：

```text
https://github.com/cuttingdust/cuttingdust-vcpkg-registry.git
```

本地结构：

```text
cuttingdust-vcpkg-registry/
  ports/
  versions/
```

初始化：

```powershell
mkdir F:\thirty\MyFile\cuttingdust-vcpkg-registry
cd F:\thirty\MyFile\cuttingdust-vcpkg-registry
git init
```

## 第四步：编写 port

`ports/mlog/vcpkg.json`：

```json
{
  "name": "mlog",
  "version": "0.1.0",
  "description": "Cross-platform logging wrapper based on spdlog",
  "homepage": "https://github.com/cuttingdust/api_mlog",
  "license": "MIT",
  "supports": "!(uwp)",
  "dependencies": [
    "spdlog",
    {
      "name": "vcpkg-cmake",
      "host": true
    },
    {
      "name": "vcpkg-cmake-config",
      "host": true
    }
  ]
}
```

`ports/mlog/portfile.cmake`：

```cmake
vcpkg_from_git(
  OUT_SOURCE_PATH SOURCE_PATH
  URL https://github.com/cuttingdust/api_mlog.git
  REF af45b6abd4dd68c265d4250da63a5ae79f8b19ce
)

vcpkg_cmake_configure(
  SOURCE_PATH "${SOURCE_PATH}/src"
  OPTIONS
    -DCMAKE_CXX_STANDARD=20
)

vcpkg_cmake_install()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
vcpkg_cmake_config_fixup(PACKAGE_NAME MLog CONFIG_PATH lib/cmake/MLog)
vcpkg_copy_pdbs()
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
```

`ports/mlog/usage`：

```text
mlog provides CMake targets:

  find_package(MLog CONFIG REQUIRED)
  target_link_libraries(main PRIVATE MLog::MLog)

And the public header:

  #include <MLog/MLog.h>
```

## 第五步：编写 versions

`versions/baseline.json`：

```json
{
  "default": {
    "mlog": {
      "baseline": "0.1.0",
      "port-version": 0
    }
  }
}
```

`versions/m-/mlog.json` 需要填写 `ports/mlog` 目录的 git tree hash。

先暂存 port：

```powershell
git add ports/mlog
git write-tree --prefix=ports/mlog/
```

命令输出类似：

```text
722bab472044561a21318d03c84e6c2639358135
```

写入 `versions/m-/mlog.json`：

```json
{
  "versions": [
    {
      "version": "0.1.0",
      "port-version": 0,
      "git-tree": "722bab472044561a21318d03c84e6c2639358135"
    }
  ]
}
```

说明：正常也可以尝试 `vcpkg x-add-version mlog --verbose`，但这次在独立 registry 本地目录里没有直接识别到 port，所以用 `git write-tree --prefix=ports/mlog/` 手动生成。

## 第六步：提交并推送 registry

```powershell
git add README.md ports versions
git commit -m "Add mlog vcpkg registry entry"
git branch -M main
git remote add origin https://github.com/cuttingdust/cuttingdust-vcpkg-registry.git
git push -u origin main
git rev-parse HEAD
```

记下 registry commit，这就是消费者项目里的 baseline。例如这次是：

```text
230be4524d1fd8e398a9f7e110278e214c5d9b2d
```

## 第七步：消费者项目使用

消费者项目根目录放 `vcpkg.json`：

```json
{
  "name": "my-app",
  "version": "0.1.0",
  "dependencies": [
    "mlog"
  ]
}
```

同目录放 `vcpkg-configuration.json`：

```json
{
  "default-registry": {
    "kind": "git",
    "repository": "https://github.com/microsoft/vcpkg",
    "baseline": "a0400024711b283056538ac19ced80b91a83c24c"
  },
  "registries": [
    {
      "kind": "git",
      "repository": "https://github.com/cuttingdust/cuttingdust-vcpkg-registry.git",
      "baseline": "230be4524d1fd8e398a9f7e110278e214c5d9b2d",
      "packages": [ "mlog" ]
    }
  ]
}
```

CMake 中：

```cmake
find_package(MLog CONFIG REQUIRED)
target_link_libraries(my_app PRIVATE MLog::MLog)
```

配置：

```powershell
cmake -B build -A x64 -S . -DCMAKE_TOOLCHAIN_FILE=$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake
cmake --build build --config Release
```

## 第八步：在本模板风格中使用

模板的根 `CMakeLists.txt` 中先找包：

```cmake
find_package(MLog CONFIG REQUIRED)
```

`CommonTools.cmake` 中定义模块变量：

```cmake
set(MLOG_MOUDLES
  MLog::MLog
)
```

具体子项目需要使用时：

```cmake
set(DPS_LIBRARYS
  ${MLOG_MOUDLES}
  ${FFMEPG_MOUDLES}
)

cpp_execute(${PROJECT_NAME})
```

C++ 代码：

```cpp
#include <MLog/MLog.h>

MInfo("hello {}", 42);
```

## 更新版本流程

以后 `mlog` 代码更新时，不是直接让消费者自动追最新，而是主动发布新 registry baseline：

1. 修改 `api_mlog` 源码。
2. 提交并推送源码库。
3. 获取新的源码 commit。
4. 修改 registry 中 `ports/mlog/portfile.cmake` 的 `REF`。
5. 如果版本号变化，修改 `ports/mlog/vcpkg.json` 的 `version`。
6. 重新生成 `ports/mlog` 的 git tree：

```powershell
git add ports/mlog
git write-tree --prefix=ports/mlog/
```

7. 更新 `versions/m-/mlog.json`。
8. 提交并推送 registry。
9. 消费者项目把 `vcpkg-configuration.json` 的 registry `baseline` 改成新的 registry commit。

## 开发阶段替代方案：overlay-ports

如果只是本机调试，不想每次都提交 registry，可以用 overlay port。

消费者项目 `vcpkg-configuration.json`：

```json
{
  "overlay-ports": [
    "F:/thirty/MyFile/api_mlog/registry/ports"
  ]
}
```

这种方式适合开发调试。正式项目建议使用 registry + baseline，稳定可复现。

## 常见问题

### 为什么不能只写 dependencies？

只有官方 vcpkg 里已有的包，才可以只写：

```json
{
  "dependencies": [ "spdlog" ]
}
```

自己的包不在官方 registry 中，所以需要 `vcpkg-configuration.json` 指向个人 registry。

### baseline 可以不填吗？

不建议。自定义 git registry 基本需要 baseline。baseline 用来锁定 registry commit，保证项目可复现。

### 更新 vcpkg 后会自动更新包吗？

不会。`baseline` 会锁定包解析版本。要更新包，需要更新 registry 并在消费者项目里更新 baseline。

### 一个 registry 只能放一个库吗？

不是。一个 registry 可以放很多库：

```text
ports/
  mlog/
  xcodec/
  image-utils/

versions/
  m-/
    mlog.json
  x-/
    xcodec.json
  i-/
    image-utils.json
```

消费者只需要在 `packages` 中列出要从这个 registry 查找的包名。
