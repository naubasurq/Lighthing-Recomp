#!/bin/bash
pgrep -x ffxiii >/dev/null || rm -f /dev/shm/xenia_memory_*
cd ~/ffxiii/out/build/linux-amd64-release && env DISABLE_VULKAN_RENDERDOC_CAPTURE_1_45=1 SDL_JOYSTICK_HIDAPI=0 XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-0 SDL_VIDEODRIVER=wayland ./ffxiii --game_data_root=$HOME/ffxiii_data --gpu_plugin=xenos --log_file=$HOME/ffxiii_run.log
