#!/bin/bash
# tools/mkref.sh for COSMOS's firmware: build the C firmware of the COSMOS
# tree (~/rk/cosmos_ref, Kalico + COSMOS's patches) for
# firmware/configs/src/<name>.in and keep its configuration and its ctr txt +
# dictionary:
#   tools/mkref_cosmos.sh <name> ...
F=${KALIRU:-$(cd "$(dirname "$0")/.." && pwd)/work/kaliru}/firmware
for N in "$@"; do
O=$HOME/rk/fw_$N
mkdir -p $O && cp $F/configs/src/$N.in $O/.config
cd ~/rk/cosmos_ref
make OUT=$O/ KCONFIG_CONFIG=$O/.config olddefconfig > /dev/null
if ! make OUT=$O/ KCONFIG_CONFIG=$O/.config -j8 > $O/build.log 2>&1; then
    echo "C build of $N failed"; tail -20 $O/build.log; continue
fi
mkdir -p $F/configs/$N
cp $O/autoconf.h $F/configs/$N/autoconf.h; cp $O/.config $F/configs/$N/config; cp $O/defconfig $F/configs/$N/defconfig
cp $O/compile_time_request.txt $F/tests/ref/${N}_compile_time_request.txt; cp $O/klipper.dict $F/tests/ref/${N}_klipper.dict
echo "== $N: $(grep 'CONFIG_MCU=' $O/.config)"
done
