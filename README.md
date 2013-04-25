resource-calculator
===================
<pre>
$ ./resource-calculator.sh 
Usage> ./resource-calculator.sh -v -r path_bin_readelf -s path_bin_strip -o output_dir -l path_for_library_finding  [ BIN_FILE | BIN_DIR | LIB_FILE | LIB_DIR ] ...

$ ./resource-calculator.sh -r `which armv6-linux-gnueabi-readelf` -s `which armv6-linux-gnueabi-strip` -l /path/arm/lib -l /path/armv6-compiler/lib -l /path/armv6-device/sysroot/lib -o calc_output /path/arm_bin_dir /path/arm_lib_dir
</pre>
