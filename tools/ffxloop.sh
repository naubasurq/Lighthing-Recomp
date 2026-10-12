#!/bin/bash
BUILD=~/ffxiii/out/build/linux-amd64-debug
for i in $(seq 1 25); do
  rm -f ~/ffxiii_last.log
  cd $BUILD
  env XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-0 SDL_VIDEODRIVER=wayland ./ffxiii --game_data_root=$HOME/ffxiii_data --gpu_plugin=xenos --log_file=$HOME/ffxiii_last.log
  a=$(grep -o "guest address 0x[0-9A-F]*" ~/ffxiii_last.log | tail -n 1 | sed 's/guest address //')
  if [ -z "$a" ]; then
    echo "SIN FATAL de funcion. Mira el log:"
    grep -i -E "fatal|critical|error" ~/ffxiii_last.log | tail -n 5 | cut -c1-170
    break
  fi
  if grep -q "^$a = " ~/ffxiii/ffxiii_manifest.toml; then
    echo "$a ya estaba en el manifest y sigue fallando"
    break
  fi
  echo "$a = { size = 0x10 }" >> ~/ffxiii/ffxiii_manifest.toml
  cd ~/ffxiii
  rexglue codegen ffxiii_manifest.toml --force --ignore-stamp > /dev/null 2>&1
  hex=${a#0x}
  c=$(sed -n "/DEFINE_REX_FUNC(sub_$hex)/,/^}/p" generated/default/ffxiii_recomp.*.cpp | grep -c -E "REX_CALL_INDIRECT_FUNC|// blr")
  if [ "$c" -lt 1 ]; then
    echo "$a NO parece un thunk. Lo quito y paro."
    sed -i '$d' ffxiii_manifest.toml
    break
  fi
  echo "agregado $a (vuelta $i)"
  cmake --build --preset linux-amd64-debug -j4 2>&1 | tail -n 1
done
echo "---- FIN ----"
tail -n 5 ~/ffxiii/ffxiii_manifest.toml
