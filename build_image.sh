#!/usr/bin/env bash
set -euo pipefail

# ArkOS4Clone 一键构建脚本
# (English: ArkOS4Clone one-click build script)
# 用法: sudo ./build_image.sh <镜像路径> [工作目录]
# (English: Usage: sudo ./build_image.sh <image_path> [work_dir])
# 工作目录用于存放镜像副本和处理文件，建议使用 ext4 文件系统以获得最佳性能
# (English: Work dir holds image copy and temp files; use ext4 for best performance)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 时间戳格式 (与 clone_support.sh 一致)
# (English: Timestamp format (aligned with clone_support.sh))
BUILD_DATE="$(TZ=Asia/Shanghai date +%m%d%Y)"
OUTPUT_NAME="ArkOS4Clone-${BUILD_DATE}"

# 颜色输出
# (English: Colored output)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

need_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    log_error "请使用 sudo 运行此脚本 (English: Please run this script with sudo)"
    exit 1
  fi
}

check_image() {
  local img="$1"
  if [[ ! -f "$img" ]]; then
    log_error "镜像文件不存在: $img (English: Image file not found)"
    exit 1
  fi
  if [[ ! -r "$img" ]]; then
    log_error "无法读取镜像文件: $img (English: Cannot read image file)"
    exit 1
  fi
  log_ok "源镜像: $img (English: Source image)"
}

check_tools() {
  local tools=(losetup mount umount parted rsync dd xz)
  for t in "${tools[@]}"; do
    if ! command -v "$t" >/dev/null 2>&1; then
      log_error "缺少工具: $t (English: Missing tool)"
      exit 1
    fi
  done
  log_ok "必需工具检查通过 (English: Required tools check passed)"
}

check_uboot_files() {
  local uboot_dir="$SCRIPT_DIR/uboot"
  local files=("idbloader.img" "uboot.img" "trust.img" "flash_uboot.sh")
  for f in "${files[@]}"; do
    if [[ ! -f "$uboot_dir/$f" ]]; then
      log_error "缺少 U-Boot 文件: $uboot_dir/$f (English: Missing U-Boot file)"
      exit 1
    fi
  done
  log_ok "U-Boot 文件检查通过 (English: U-Boot files check passed)"
}

check_jdk_file() {
  local jdk_file="zulu11.48.21-ca-jdk11.0.11-linux_aarch64.tar.gz"
  local jdk_url="https://cdn.azul.com/zulu-embedded/bin/zulu11.48.21-ca-jdk11.0.11-linux_aarch64.tar.gz"
  
  if [[ -f "$SCRIPT_DIR/$jdk_file" ]]; then
    log_ok "JDK 文件已存在: $jdk_file (English: JDK file already exists)"
    return
  fi
  
  log_info "下载 JDK 文件... (English: Downloading JDK file...)"
  # 以原用户身份下载（避免权限问题）
  # (English: Download as original user to avoid permission issues)
  if [[ -n "${SUDO_USER:-}" ]]; then
    if sudo -u "$SUDO_USER" wget -q --show-progress -O "$SCRIPT_DIR/$jdk_file" "$jdk_url"; then
      log_ok "JDK 下载完成: $jdk_file (English: JDK download complete)"
    else
      log_error "JDK 下载失败 (English: JDK download failed)"
      sudo -u "$SUDO_USER" rm -f "$SCRIPT_DIR/$jdk_file" 2>/dev/null || true
      exit 1
    fi
  else
    if wget -q --show-progress -O "$SCRIPT_DIR/$jdk_file" "$jdk_url"; then
      log_ok "JDK 下载完成: $jdk_file (English: JDK download complete)"
    else
      log_error "JDK 下载失败 (English: JDK download failed)"
      rm -f "$SCRIPT_DIR/$jdk_file" 2>/dev/null || true
      exit 1
    fi
  fi
}

check_pm_libs() {
  local pm_libs_dir="$SCRIPT_DIR/bin/pm_libs"
  local runtimes_url="https://github.com/PortsMaster/PortMaster-New/releases/download/2025-11-18_1011/runtimes.all.aarch64.zip"

  # 需要的文件列表
  # (English: Required file list)
  local required_files=(
    "ags_3.6.squashfs"
    "dotnet-8.0.12.squashfs"
    "frt_2.1.6.squashfs"
    "frt_3.0.6_v1.squashfs"
    "frt_3.1.2.squashfs"
    "frt_3.2.3.squashfs"
    "frt_3.3.4.squashfs"
    "frt_3.4.5.squashfs"
    "frt_3.5.2.squashfs"
    "frt_3.5.3.squashfs"
    "frt_3.6.squashfs"
    "frt_4.0.4.squashfs"
    "frt_4.1.3.squashfs"
    "gmtoolkit.squashfs"
    "godot_4.2.2.mono.squashfs"
    "godot_4.2.2.squashfs"
    "godot_4.3.mono.squashfs"
    "godot_4.3.squashfs"
    "godot_4.4.1.mono.squashfs"
    "godot_4.4.1.squashfs"
    "godot_4.4.mono.squashfs"
    "godot_4.4.squashfs"
    "godot_4.5.mono.squashfs"
    "godot_4.5.squashfs"
    "mesa_pkg_0.1.squashfs"
    "mono-6.12.0.122-aarch64.squashfs"
    "python_3.11.squashfs"
    "pyxel_2.2.8_python_3.11.squashfs"
    "pyxel_2.3.18_python_3.11.squashfs"
    "pyxel_2.4.6_python_3.11.squashfs"
    "renpy_8.1.3.squashfs"
    "renpy_8.3.4.squashfs"
    "rlvm.squashfs"
    "solarus-1.6.5.squashfs"
    "weston_pkg_0.2.squashfs"
    "zulu11.48.21-ca-jdk11.0.11-linux.squashfs"
    "zulu17.48.15-ca-jdk17.0.10-linux.squashfs"
    "zulu17.54.21-ca-jre17.0.13-linux.squashfs"
    "zulu23.32.11-ca-jre23.0.2-linux.squashfs"
    "zulu8.86.0.25-ca-jdk8.0.452-linux.squashfs"
  )

  # 检查目录是否存在
  # (English: Check if directory exists)
  if [[ ! -d "$pm_libs_dir" ]]; then
    mkdir -p "$pm_libs_dir"
  fi

  # 检查缺少的文件
  # (English: Check for missing files)
  local missing=0
  for f in "${required_files[@]}"; do
    if [[ ! -f "$pm_libs_dir/$f" ]]; then
      missing=1
      break
    fi
  done

  if [[ $missing -eq 0 ]]; then
    log_ok "pm_libs 文件完整 (English: pm_libs files complete)"
    return
  fi

  log_info "下载 PortMaster runtimes (约 1.6GB)... (English: Downloading PortMaster runtimes (~1.6GB)...)"
  local zip_file="$pm_libs_dir/runtimes.zip"

  # 下载
  # (English: Download)
  if [[ -n "${SUDO_USER:-}" ]]; then
    if sudo -u "$SUDO_USER" wget --progress=bar:force -O "$zip_file" "$runtimes_url"; then
      log_ok "runtimes 下载完成 (English: runtimes download complete)"
    else
      log_error "runtimes 下载失败 (English: runtimes download failed)"
      sudo -u "$SUDO_USER" rm -f "$zip_file" 2>/dev/null || true
      exit 1
    fi
    # 解压
    # (English: Extract)
    log_info "解压 runtimes... (English: Extracting runtimes...)"
    sudo -u "$SUDO_USER" unzip -o -q "$zip_file" -d "$pm_libs_dir"
    sudo -u "$SUDO_USER" rm -f "$zip_file"
  else
    if wget --progress=bar:force -O "$zip_file" "$runtimes_url"; then
      log_ok "runtimes 下载完成 (English: runtimes download complete)"
    else
      log_error "runtimes 下载失败 (English: runtimes download failed)"
      rm -f "$zip_file" 2>/dev/null || true
      exit 1
    fi
    # 解压
    # (English: Extract)
    log_info "解压 runtimes... (English: Extracting runtimes...)"
    unzip -o -q "$zip_file" -d "$pm_libs_dir"
    rm -f "$zip_file"
  fi

  log_ok "pm_libs 文件准备完成 (English: pm_libs preparation complete)"
}

check_work_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    log_info "创建工作目录: $dir (English: Creating work directory)"
    mkdir -p "$dir"
  fi
  # 检查是否可写
  # (English: Check if writable)
  if [[ ! -w "$dir" ]]; then
    log_error "工作目录不可写: $dir (English: Work directory not writable)"
    exit 1
  fi
  log_ok "工作目录: $dir (English: Work directory)"
}

check_portmaster() {
  local pm_dir="$SCRIPT_DIR/PortMaster"
  local pm_url="https://github.com/PortsMaster/PortMaster-GUI/releases/download/2026.03.09-2312/PortMaster.zip"

  if [[ -d "$pm_dir" && -f "$pm_dir/PortMaster.sh" ]]; then
    log_ok "PortMaster 目录已存在 (English: PortMaster directory already exists)"
    return
  fi

  log_info "下载 PortMaster... (English: Downloading PortMaster...)"
  local zip_file="$SCRIPT_DIR/PortMaster.zip"

  if [[ -n "${SUDO_USER:-}" ]]; then
    if sudo -u "$SUDO_USER" wget -q --show-progress -O "$zip_file" "$pm_url"; then
      log_ok "PortMaster 下载完成 (English: PortMaster download complete)"
    else
      log_error "PortMaster 下载失败 (English: PortMaster download failed)"
      sudo -u "$SUDO_USER" rm -f "$zip_file" 2>/dev/null || true
      exit 1
    fi
    log_info "解压 PortMaster... (English: Extracting PortMaster...)"
    sudo -u "$SUDO_USER" unzip -q -o "$zip_file" -d "$SCRIPT_DIR"
    sudo -u "$SUDO_USER" rm -f "$zip_file"
  else
    if wget -q --show-progress -O "$zip_file" "$pm_url"; then
      log_ok "PortMaster 下载完成 (English: PortMaster download complete)"
    else
      log_error "PortMaster 下载失败 (English: PortMaster download failed)"
      rm -f "$zip_file" 2>/dev/null || true
      exit 1
    fi
    log_info "解压 PortMaster... (English: Extracting PortMaster...)"
    unzip -q -o "$zip_file" -d "$SCRIPT_DIR"
    rm -f "$zip_file"
  fi

  log_ok "PortMaster 准备完成 (English: PortMaster preparation complete)"
}

check_clone_dependencies() {
  log_info "检查 clone_support.sh 依赖... (English: Checking clone_support.sh dependencies...)"
  local missing=0
  local missing_list=""

  # 检查必需目录
  # (English: Check required directories)
  local dirs=(
    "consoles"
    "bin"
    "bin/adc-key"
    "bin/aic8800DC"
    "bin/json-c3"
    "mod_so/32"
    "mod_so/64"
    "replace_file"
    "replace_file/drastic"
    "replace_file/drastic-kk"
    "replace_file/ppsspp"
    "replace_file/pymo"
    "replace_file/resources"
    "replace_file/retrorun"
    "replace_file/scummvm"
    "replace_file/services"
    "replace_file/tools"
    "res"
    "sh"
    "Jason3_Scripte"
    "Jason3_Scripte/Bluetooth-Manager"
    "Jason3_Scripte/GhostLoader"
    "Jason3_Scripte/InfoSystem"
    "Jason3_Scripte/wifi-toggle"
  )

  for d in "${dirs[@]}"; do
    if [[ ! -d "$SCRIPT_DIR/$d" ]]; then
      missing=1
      missing_list="$missing_list\n  缺少目录: $d (English: missing directory)"
    fi
  done

  # 检查必需文件
  # (English: Check required files)
  local files=(
    "dtb_selector_macos"
    "dtb_selector_win32.exe"
    "sh/clone.sh"
    "sh/expandtoexfat.sh"
    "sh/darkos-expandtoexfat.sh"
    "bin/mcu_led"
    "bin/ws2812"
    "bin/sdljoymap"
    "bin/sdljoytest"
    "bin/console_detect"
    "bin/adc-key/adckeys.py"
    "bin/adc-key/adckeys.sh"
    "bin/adc-key/adckeys.service"
    "replace_file/es_systems.cfg"
    "replace_file/es_systems.cfg.dual"
    "replace_file/emulationstation"
    "replace_file/pymo/cpymo"
    "replace_file/pymo/pymo.sh"
    "replace_file/pymo/Scan_for_new_games.pymo"
    "replace_file/retrorun/retrorun"
    "replace_file/retrorun/retrorun32"
    "replace_file/services/351mp.service"
    "Jason3_Scripte/Bluetooth-Manager/Bluetooth Manager.sh"
    "Jason3_Scripte/Bluetooth-Manager/patch.pak"
    "Jason3_Scripte/GhostLoader/GhostLoader.sh"
    "Jason3_Scripte/InfoSystem/InfoSystem.sh"
    "Jason3_Scripte/wifi-toggle/Wifi-toggle.sh"
  )

  for f in "${files[@]}"; do
    if [[ ! -f "$SCRIPT_DIR/$f" ]]; then
      missing=1
      missing_list="$missing_list\n  缺少文件: $f (English: missing file)"
    fi
  done

  if [[ $missing -eq 1 ]]; then
    log_error "clone_support.sh 依赖检查失败 (English: clone_support.sh dependency check failed)"
    echo -e "$missing_list"
    exit 1
  fi

  log_ok "clone_support.sh 依赖检查通过 (English: clone_support.sh dependency check passed)"
}

step_build_dtb_selector() {
  log_info "步骤 0: 编译 dtb_selector 工具... (English: Step 0: Building dtb_selector tool...)"
  if [[ -f "$SCRIPT_DIR/build_dtb_selector.sh" ]]; then
    cd "$SCRIPT_DIR"
    # 以原用户身份执行编译（保留 PATH 环境变量）
    # (English: Run build as original user, keep PATH)
    if [[ -n "${SUDO_USER:-}" ]]; then
      if sudo -u "$SUDO_USER" env PATH="$PATH" ./build_dtb_selector.sh; then
        log_ok "dtb_selector 编译完成 (English: dtb_selector build complete)"
      else
        log_warn "dtb_selector 编译失败，跳过（可能已存在） (English: dtb_selector build failed, skipping)"
      fi
    else
      if ./build_dtb_selector.sh; then
        log_ok "dtb_selector 编译完成 (English: dtb_selector build complete)"
      else
        log_warn "dtb_selector 编译失败，跳过（可能已存在） (English: dtb_selector build failed, skipping)"
      fi
    fi
    cd - > /dev/null
  else
    log_warn "未找到 build_dtb_selector.sh，跳过 (English: build_dtb_selector.sh not found, skipping)"
  fi
}

copy_image() {
  local src="$1"
  local dst="$2"
  log_info "复制源镜像到工作目录... (English: Copying source image to work directory...)"
  cp "$src" "$dst"
  log_ok "已创建工作副本: $dst (English: Work copy created)"
}

step_grow() {
  local img="$1"
  log_info "步骤 2/7: 扩容镜像分区... (English: Step 2/7: Expanding image partition...)"
  if "$SCRIPT_DIR/grow_p2_plus.sh" "$img"; then
    log_ok "分区扩容完成 (English: Partition expansion complete)"
  else
    log_error "分区扩容失败 (English: Partition expansion failed)"
    exit 1
  fi
}

step_flash_uboot() {
  local img="$1"
  log_info "步骤 3/7: 写入 U-Boot... (English: Step 3/7: Writing U-Boot...)"
  # 需要在 uboot 目录下执行，并使用绝对路径
  # (English: Must run from uboot dir and use absolute path)
  local abs_img
  if [[ "$img" = /* ]]; then
    abs_img="$img"
  else
    abs_img="$(pwd)/$img"
  fi
  cd "$SCRIPT_DIR/uboot"
  if ./flash_uboot.sh -y -i "$abs_img"; then
    log_ok "U-Boot 写入完成 (English: U-Boot write complete)"
  else
    log_error "U-Boot 写入失败 (English: U-Boot write failed)"
    cd "$SCRIPT_DIR"
    exit 1
  fi
  cd "$SCRIPT_DIR"
}

step_mount() {
  local img="$1"
  log_info "步骤 4/7: 挂载镜像... (English: Step 4/7: Mounting image...)"
  if "$SCRIPT_DIR/mount_arkos.sh" mount "$img"; then
    log_ok "镜像挂载完成 (English: Image mount complete)"
  else
    log_error "镜像挂载失败 (English: Image mount failed)"
    exit 1
  fi
}

step_inject() {
  log_info "步骤 5/7: 注入定制内容... (English: Step 5/7: Injecting custom content...)"
  if "$SCRIPT_DIR/clone_support.sh"; then
    log_ok "内容注入完成 (English: Content injection complete)"
  else
    log_error "内容注入失败 (English: Content injection failed)"
    # 尝试卸载
    # (English: Try to unmount)
    "$SCRIPT_DIR/mount_arkos.sh" unmount 2>/dev/null || true
    exit 1
  fi
}

step_unmount() {
  log_info "步骤 6/7: 卸载镜像... (English: Step 6/7: Unmounting image...)"
  if "$SCRIPT_DIR/mount_arkos.sh" unmount; then
    log_ok "镜像卸载完成 (English: Image unmount complete)"
  else
    log_error "镜像卸载失败 (English: Image unmount failed)"
    exit 1
  fi
}

step_compress() {
  local img="$1"
  local xz_file="${img}.xz"
  log_info "步骤 7/7: 压缩镜像 (xz -5)... (English: Step 7/7: Compressing image (xz -5)...)"
  
  # 压缩等级 5，多线程
  # (English: Compression level 5, multi-threaded)
  if xz -5 -T0 -v "$img"; then
    log_ok "压缩完成: $xz_file (English: Compression complete)"
    log_ok "文件大小: $(du -h "$xz_file" | cut -f1) (English: File size)"
  else
    log_error "压缩失败 (English: Compression failed)"
    exit 1
  fi
}

move_to_script_dir() {
  local xz_file="$1"
  local dest="$SCRIPT_DIR/$(basename "$xz_file")"
  log_info "移动输出文件到脚本目录... (English: Moving output to script directory...)"
  mv "$xz_file" "$dest"
  log_ok "输出文件: $dest (English: Output file)"
}

show_usage() {
  cat << USAGE
ArkOS4Clone 一键构建脚本
(English: ArkOS4Clone one-click build script)

用法:
(English: Usage:)
  sudo ./build_image.sh <源镜像路径> [工作目录]
  (English: sudo ./build_image.sh <source_image_path> [work_dir])

参数:
(English: Arguments:)
  源镜像路径    必需，原始 ArkOS 镜像文件路径
  (English: source_image_path  Required, path to original ArkOS image)
  工作目录      可选，用于存放镜像副本和处理文件
                建议使用 ext4 文件系统以获得最佳性能
                默认: 源镜像所在目录
  (English: work_dir  Optional, for image copy and temp files; use ext4; default: same dir as source)

环境变量:
(English: Environment:)
  ARKOS_MNT       挂载路径 (默认: <工作目录>/mnt)
  (English: ARKOS_MNT  Mount path (default: <work_dir>/mnt))
  ARKOS_WORK_DIR  临时工作目录 (默认: <工作目录>)
  (English: ARKOS_WORK_DIR  Work dir (default: <work_dir>))

示例:
(English: Examples:)
  # 使用默认工作目录（源镜像所在目录）
  # (English: Use default work dir (source image directory))
  sudo ./build_image.sh /path/to/ArkOS-*.img

  # 指定工作目录（推荐，使用 ext4 文件系统）
  # (English: Specify work dir (recommended, use ext4))
  sudo ./build_image.sh /mnt/e/ArkOS.img /home/lcdyk/arkos

执行步骤:
(English: Steps:)
  0. 编译 dtb_selector 工具 (build_dtb_selector.sh)
  (English: Build dtb_selector (build_dtb_selector.sh))
  1. 复制源镜像到工作目录
  (English: Copy source image to work dir)
  2. 扩容镜像分区 (grow_p2_plus.sh)
  (English: Expand partition (grow_p2_plus.sh))
  3. 写入 U-Boot (flash_uboot.sh)
  (English: Write U-Boot (flash_uboot.sh))
  4. 挂载镜像 (mount_arkos.sh mount)
  (English: Mount image (mount_arkos.sh mount))
  5. 注入定制内容 (clone_support.sh)
  (English: Inject content (clone_support.sh))
  6. 卸载镜像 (mount_arkos.sh unmount)
  (English: Unmount image (mount_arkos.sh unmount))
  7. 压缩为 xz 格式 (等级 5)
  (English: Compress to xz (level 5))
  8. 移动输出文件到脚本目录
  (English: Move output to script dir)

输出:
(English: Output:)
  <脚本目录>/ArkOS4Clone-MMDDYYYY.img.xz
  (English: <script_dir>/ArkOS4Clone-MMDDYYYY.img.xz)

注意:
(English: Notes:)
  - 源镜像文件不会被修改
  (English: Source image is not modified)
  - 工作目录建议使用 ext4 文件系统，避免 WSL 的 /mnt 路径以提高性能
  (English: Use ext4 for work dir; avoid WSL /mnt for better performance)

USAGE
}

main() {
  # 首先检查 root 权限
  # (English: Check root first)
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    log_error "请使用 sudo 运行此脚本 (English: Please run this script with sudo)"
    exit 1
  fi

  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_usage
    exit 0
  fi

  if [[ $# -lt 1 ]]; then
    log_error "缺少参数: 镜像路径 (English: Missing argument: image path)"
    echo ""
    show_usage
    exit 1
  fi

  local source_image="$1"
  
  # 确定工作目录
  # (English: Determine work directory)
  local work_dir
  if [[ $# -ge 2 ]]; then
    work_dir="$2"
  else
    # 默认使用源镜像所在目录
    # (English: Default: source image directory)
    work_dir="$(cd "$(dirname "$source_image")" && pwd)"
  fi
  
  # 转换为绝对路径
  # (English: Convert to absolute path)
  if [[ "$work_dir" != /* ]]; then
    work_dir="$(pwd)/$work_dir"
  fi

  # 设置环境变量
  # (English: Set environment variables)
  ARKOS_MNT="${ARKOS_MNT:-${work_dir}/mnt}"
  ARKOS_WORK_DIR="${ARKOS_WORK_DIR:-${work_dir}}"
  ARKOS_IMAGE_NAME="$(basename "$source_image")"
  export ARKOS_MNT ARKOS_WORK_DIR ARKOS_IMAGE_NAME

  # 根据源镜像名决定输出前缀
  # (English: Output prefix from source image name)
  local output_prefix
  if [[ "$ARKOS_IMAGE_NAME" == *dArkOS* ]]; then
    output_prefix="dArkOS4Clone"
  else
    output_prefix="ArkOS4Clone"
  fi
  local work_image="${work_dir}/${output_prefix}-${BUILD_DATE}.img"

  echo "========================================"
  echo "  ArkOS4Clone 一键构建脚本"
  echo "  (English: ArkOS4Clone one-click build script)"
  echo "========================================"
  echo "源镜像:   $source_image"
  echo "(English: Source image)"
  echo "工作目录: $work_dir"
  echo "(English: Work dir)"
  echo "工作副本: $work_image"
  echo "(English: Work copy)"
  echo "挂载路径: $ARKOS_MNT"
  echo "(English: Mount path)"
  echo "========================================"
  echo ""

  # 步骤 0: 编译 dtb_selector (不需要 root)
  # (English: Step 0: Build dtb_selector (no root))
  step_build_dtb_selector
  echo ""

  # 前置检查 (不需要 root)
  # (English: Pre-checks (no root))
  check_tools
  check_jdk_file
  check_portmaster
  check_pm_libs
  check_clone_dependencies

  # 需要 root 的检查
  # (English: Checks that need root)
  check_image "$source_image"
  check_work_dir "$work_dir"
  check_uboot_files

  # 步骤 1: 复制镜像
  # (English: Step 1: Copy image)
  echo ""
  copy_image "$source_image" "$work_image"

  # 执行构建流程
  # (English: Run build pipeline)
  echo ""
  step_grow "$work_image"
  echo ""
  step_flash_uboot "$work_image"
  echo ""
  step_mount "$work_image"
  echo ""
  step_inject
  echo ""
  step_unmount

  # 压缩并移动
  # (English: Compress and move)
  echo ""
  step_compress "$work_image"
  move_to_script_dir "${work_image}.xz"

  echo ""
  echo "========================================"
  log_ok "构建完成! (English: Build complete!)"
  echo "输出文件: $SCRIPT_DIR/$(basename "${work_image}").xz"
  echo "(English: Output file)"
  echo "源文件保留: $source_image"
  echo "(English: Source file preserved)"
  echo "========================================"
}

main "$@"
