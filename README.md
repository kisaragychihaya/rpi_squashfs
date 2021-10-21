# rpi_squashfs
一个简陋的工具：压缩并锁定树莓派的系统分区，支持一键恢复出厂
-------------------------------------------------------
首先编译并安装自己的内核，可参考官方文档 https://www.raspberrypi.com/documentation/computers/linux_kernel.html

将项目git clone到树莓派，运行```bash rpi*.sh```

确保需要修改的东西已经写入，因为压缩文件系统的性质，一旦压缩将无法修改

关机，拔下SD卡，插入安装了mksquashfs工具的系统

运行```bash gen_img.sh <SD卡块设备>```

等待生成新的img文件

第一次开机默认不挂载读写分区 可输入expandfs.sh 将读写分区从512M扩容到整个SD卡

清除修改只需要在boot分区下放入wipedata空文件重新启动时自动清除修改
