# bug fix layer (`rel-v2024.2` branch) 

## `qemu-xilinx-native` recipe

`struct sched_attr`の二重定義エラーが発生する。
Linux Kernel v6.13.2のような最新のカーネルを使っているときに、`/usr/include/linux/sched/types.h`の定義と重複する。

レシピに次のパッチを当てることで、二重定義を解消する。
- `/usr/include/linux/sched/types.h`のインクルードガード(`_LINUX_SCHED_TYPES_H`)を利用して、ビルド時に読み込まないようにする。
```
diff --git a/linux-user/syscall.c b/linux-user/syscall.c
index ca90186405..c0c430810b 100644
--- a/linux-user/syscall.c
+++ b/linux-user/syscall.c
@@ -360,6 +360,7 @@ _syscall3(int, sys_sched_getaffinity, pid_t, pid, unsigned int, len,
 _syscall3(int, sys_sched_setaffinity, pid_t, pid, unsigned int, len,
           unsigned long *, user_mask_ptr);
 /* sched_attr is not defined in glibc */
+#ifndef _LINUX_SCHED_TYPES_H
 struct sched_attr {
     uint32_t size;
     uint32_t sched_policy;
@@ -372,6 +373,7 @@ struct sched_attr {
     uint32_t sched_util_min;
     uint32_t sched_util_max;
 };
+#endif /* _LINUX_SCHED_TYPES_H */
 #define __NR_sys_sched_getattr __NR_sched_getattr
 _syscall4(int, sys_sched_getattr, pid_t, pid, struct sched_attr *, attr,
           unsigned int, size, unsigned int, flags);
```
